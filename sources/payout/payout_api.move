// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Automated Payout System
/// Handles instant escrow release after triage finalization
module suiguard::payout_api {
    use sui::object::{Self, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::sui::SUI;
    use sui::transfer;

    use suiguard::report_types::{Self, BugReport};
    use suiguard::bounty_types::{Self, BountyProgram};
    use suiguard::triage_types::{Self, TriageVote};
    use suiguard::payout_events;

    // ======== Error Codes ========

    const E_NOT_RESEARCHER: u64 = 6000;
    const E_PAYOUT_ALREADY_EXECUTED: u64 = 6001;
    const E_REPORT_NOT_ACCEPTED: u64 = 6002;
    const E_TRIAGE_NOT_FINALIZED: u64 = 6003;
    const E_INSUFFICIENT_ESCROW: u64 = 6004;
    const E_INVALID_SEVERITY: u64 = 6005;
    const E_HAS_SPLIT_PROPOSAL: u64 = 6006;
    const E_NOT_PROGRAM_OWNER: u64 = 6007;

    // ======== Entry Functions ========

    /// Execute automatic payout after report is accepted
    /// Can be called by researcher or program owner
    /// Transfers funds directly from escrow to researcher
    public entry fun execute_payout(
        report: &mut BugReport,
        program: &mut BountyProgram,
        ctx: &mut TxContext,
    ) {
        // Verify caller is researcher or program owner
        let caller = tx_context::sender(ctx);
        let is_researcher = caller == report_types::researcher(report);
        let is_owner = caller == bounty_types::project_owner(program);
        assert!(is_researcher || is_owner, E_NOT_RESEARCHER);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_NOT_PROGRAM_OWNER);

        // Verify report is accepted
        assert!(report_types::is_accepted(report), E_REPORT_NOT_ACCEPTED);

        // Verify payout not already executed
        assert!(!report_types::payout_executed(report), E_PAYOUT_ALREADY_EXECUTED);

        // Verify no pending split proposal
        assert!(!report_types::has_split_proposal(report), E_HAS_SPLIT_PROPOSAL);

        // Get severity tier payout amount
        let severity = report_types::severity(report);
        let payout_amount = bounty_types::get_severity_payout(program, severity);
        assert!(payout_amount > 0, E_INVALID_SEVERITY);

        // Verify sufficient escrow
        assert!(bounty_types::total_escrow_value(program) >= payout_amount, E_INSUFFICIENT_ESCROW);

        let timestamp = tx_context::epoch(ctx);

        // Withdraw from escrow
        let payout_balance = balance::split(bounty_types::escrow_mut(program), payout_amount);

        // Update report payout status
        report_types::set_payout_amount(report, payout_amount);
        report_types::execute_payout_internal(report, timestamp);

        // Update program statistics
        bounty_types::increment_reports_resolved(program);
        bounty_types::add_payout(program, payout_amount);

        // Update report status to PAID
        report_types::set_status(report, report_types::status_paid());

        // Transfer to researcher
        let researcher = report_types::researcher(report);
        let payout_coin = coin::from_balance(payout_balance, ctx);
        transfer::public_transfer(payout_coin, researcher);

        // Refund submission fee
        let fee = report_types::withdraw_fee(report);
        let fee_coin = coin::from_balance(fee, ctx);
        transfer::public_transfer(fee_coin, researcher);

        // Emit payout event
        payout_events::emit_payout_executed(
            object::uid_to_inner(report_types::id(report)),
            program_id,
            researcher,
            payout_amount,
            severity,
            timestamp,
        );
    }

    /// Claim payout after triage finalization
    /// Alternative pull payment pattern
    /// Allows researcher to claim after DAO verdict
    public entry fun claim_payout(
        report: &mut BugReport,
        program: &mut BountyProgram,
        vote: &TriageVote,
        ctx: &mut TxContext,
    ) {
        // Verify caller is researcher
        let caller = tx_context::sender(ctx);
        assert!(caller == report_types::researcher(report), E_NOT_RESEARCHER);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_NOT_PROGRAM_OWNER);

        // Verify triage vote is finalized
        assert!(triage_types::is_finalized(vote), E_TRIAGE_NOT_FINALIZED);

        // Verify vote is for this report
        let report_id = object::uid_to_inner(report_types::id(report));
        assert!(triage_types::report_id(vote) == report_id, E_TRIAGE_NOT_FINALIZED);

        // Verify payout not already executed
        assert!(!report_types::payout_executed(report), E_PAYOUT_ALREADY_EXECUTED);

        // Verify no pending split proposal
        assert!(!report_types::has_split_proposal(report), E_HAS_SPLIT_PROPOSAL);

        // Get finalized severity from triage
        let final_severity = triage_types::final_severity(vote);

        // Update report severity if it was triaged
        if (report_types::severity(report) != final_severity) {
            report_types::set_severity(report, final_severity);
        };

        // Get payout amount for finalized severity
        let payout_amount = bounty_types::get_severity_payout(program, final_severity);
        assert!(payout_amount > 0, E_INVALID_SEVERITY);

        // Verify sufficient escrow
        assert!(bounty_types::total_escrow_value(program) >= payout_amount, E_INSUFFICIENT_ESCROW);

        let timestamp = tx_context::epoch(ctx);

        // Withdraw from escrow
        let payout_balance = balance::split(bounty_types::escrow_mut(program), payout_amount);

        // Update report payout status
        report_types::set_payout_amount(report, payout_amount);
        report_types::execute_payout_internal(report, timestamp);

        // Update program statistics
        bounty_types::increment_reports_resolved(program);
        bounty_types::add_payout(program, payout_amount);

        // Update report status to PAID and ACCEPTED
        report_types::set_status(report, report_types::status_paid());
        if (!report_types::is_accepted(report)) {
            report_types::set_status(report, report_types::status_accepted());
        };

        // Transfer to researcher
        let researcher = report_types::researcher(report);
        let payout_coin = coin::from_balance(payout_balance, ctx);
        transfer::public_transfer(payout_coin, researcher);

        // Refund submission fee
        let fee = report_types::withdraw_fee(report);
        let fee_coin = coin::from_balance(fee, ctx);
        transfer::public_transfer(fee_coin, researcher);

        // Emit payout event
        payout_events::emit_payout_executed(
            report_id,
            program_id,
            researcher,
            payout_amount,
            final_severity,
            timestamp,
        );
    }

    // ======== View Functions ========

    /// Check if a report is eligible for payout
    /// Returns (eligible, reason_code, payout_amount)
    /// reason_code: 0=eligible, 1=not_accepted, 2=already_paid, 3=has_split, 4=insufficient_escrow
    public fun check_payout_eligibility(
        report: &BugReport,
        program: &BountyProgram,
    ): (bool, u8, u64) {
        // Check if already paid
        if (report_types::payout_executed(report)) {
            return (false, 2, 0)
        };

        // Check if has split proposal
        if (report_types::has_split_proposal(report)) {
            return (false, 3, 0)
        };

        // Check if accepted
        if (!report_types::is_accepted(report)) {
            return (false, 1, 0)
        };

        // Get payout amount
        let severity = report_types::severity(report);
        let payout_amount = bounty_types::get_severity_payout(program, severity);

        // Check escrow
        if (bounty_types::total_escrow_value(program) < payout_amount) {
            return (false, 4, payout_amount)
        };

        (true, 0, payout_amount)
    }

    /// Get payout details for a report
    /// Returns (amount, executed, executed_at)
    public fun get_payout_details(report: &BugReport): (u64, bool, u64) {
        let amount = report_types::payout_amount(report);
        let executed = report_types::payout_executed(report);
        let executed_at = if (report_types::payout_executed(report)) {
            let at_opt = report_types::payout_executed_at(report);
            if (std::option::is_some(&at_opt)) {
                *std::option::borrow(&at_opt)
            } else {
                0
            }
        } else {
            0
        };

        (amount, executed, executed_at)
    }
}
