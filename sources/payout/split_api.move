// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Split Payment System
/// Allows primary researcher to split rewards with co-finders
module suiguard::split_api {
    use std::vector;
    use sui::object::{Self, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::sui::SUI;
    use sui::transfer;

    use suiguard::report_types::{Self, BugReport};
    use suiguard::bounty_types::{Self, BountyProgram};
    use suiguard::payout_types::{Self, SplitProposal, SplitRecipient};
    use suiguard::payout_events;

    // ======== Error Codes ========

    const E_NOT_RESEARCHER: u64 = 7000;
    const E_PAYOUT_ALREADY_EXECUTED: u64 = 7001;
    const E_REPORT_NOT_ACCEPTED: u64 = 7002;
    const E_ALREADY_HAS_SPLIT: u64 = 7003;
    const E_NOT_RECIPIENT: u64 = 7004;
    const E_ALREADY_APPROVED: u64 = 7005;
    const E_NOT_ALL_APPROVED: u64 = 7006;
    const E_ALREADY_EXECUTED: u64 = 7007;
    const E_INSUFFICIENT_ESCROW: u64 = 7008;
    const E_INVALID_PROPOSAL: u64 = 7009;
    const E_NOT_PRIMARY_RESEARCHER: u64 = 7010;

    // ======== Entry Functions ========

    /// Propose a split payment among multiple researchers
    /// Primary researcher creates proposal with percentage splits
    /// All recipients must approve before execution
    public entry fun propose_split(
        report: &mut BugReport,
        program: &BountyProgram,
        recipients: vector<address>,
        percentages_bp: vector<u64>,
        ctx: &mut TxContext,
    ) {
        // Verify caller is the primary researcher
        let caller = tx_context::sender(ctx);
        assert!(caller == report_types::researcher(report), E_NOT_RESEARCHER);

        // Verify report is accepted
        assert!(report_types::is_accepted(report), E_REPORT_NOT_ACCEPTED);

        // Verify payout not already executed
        assert!(!report_types::payout_executed(report), E_PAYOUT_ALREADY_EXECUTED);

        // Verify no existing split proposal
        assert!(!report_types::has_split_proposal(report), E_ALREADY_HAS_SPLIT);

        // Verify vectors have same length
        assert!(vector::length(&recipients) == vector::length(&percentages_bp), E_INVALID_PROPOSAL);

        // Get payout amount
        let severity = report_types::severity(report);
        let total_amount = bounty_types::get_severity_payout(program, severity);

        // Create split recipients
        let mut split_recipients = vector::empty<SplitRecipient>();
        let mut i = 0;
        let len = vector::length(&recipients);
        while (i < len) {
            let recipient_addr = *vector::borrow(&recipients, i);
            let percentage = *vector::borrow(&percentages_bp, i);
            let split_recipient = payout_types::new_split_recipient(recipient_addr, percentage);
            vector::push_back(&mut split_recipients, split_recipient);
            i = i + 1;
        };

        let timestamp = tx_context::epoch(ctx);
        let report_id = object::uid_to_inner(report_types::id(report));

        // Create split proposal
        let proposal = payout_types::new_split_proposal(
            report_id,
            caller,
            split_recipients,
            total_amount,
            timestamp,
            ctx,
        );

        let proposal_id = object::uid_to_inner(payout_types::id(&proposal));

        // Link proposal to report
        report_types::set_split_proposal(report, proposal_id);

        // Emit event
        payout_events::emit_split_proposal_created(
            proposal_id,
            report_id,
            caller,
            total_amount,
            len,
            timestamp,
        );

        // Transfer proposal to primary researcher
        transfer::public_transfer(proposal, caller);
    }

    /// Approve split proposal
    /// Each recipient must call this to approve their share
    public entry fun approve_split(
        proposal: &mut SplitProposal,
        ctx: &TxContext,
    ) {
        // Verify caller is a recipient
        let caller = tx_context::sender(ctx);
        assert!(payout_types::has_recipient(proposal, caller), E_NOT_RECIPIENT);

        // Approve for this recipient
        payout_types::approve_recipient(proposal, caller);

        let timestamp = tx_context::epoch(ctx);

        // Emit event
        payout_events::emit_split_approved(
            object::uid_to_inner(payout_types::id(proposal)),
            payout_types::report_id(proposal),
            caller,
            timestamp,
        );
    }

    /// Execute split payout after all approvals
    /// Distributes funds to all recipients according to their percentages
    public entry fun execute_split_payout(
        proposal: &mut SplitProposal,
        report: &mut BugReport,
        program: &mut BountyProgram,
        ctx: &mut TxContext,
    ) {
        // Verify caller is primary researcher or any recipient
        let caller = tx_context::sender(ctx);
        let is_primary = caller == payout_types::primary_researcher(proposal);
        let is_recipient = payout_types::has_recipient(proposal, caller);
        assert!(is_primary || is_recipient, E_NOT_RESEARCHER);

        // Verify report matches proposal
        let report_id = object::uid_to_inner(report_types::id(report));
        assert!(payout_types::report_id(proposal) == report_id, E_INVALID_PROPOSAL);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_INVALID_PROPOSAL);

        // Verify all approved
        assert!(payout_types::all_approved(proposal), E_NOT_ALL_APPROVED);

        // Verify not already executed
        assert!(!payout_types::executed(proposal), E_ALREADY_EXECUTED);

        // Verify payout not already executed on report
        assert!(!report_types::payout_executed(report), E_PAYOUT_ALREADY_EXECUTED);

        let total_amount = payout_types::total_amount(proposal);

        // Verify sufficient escrow
        assert!(bounty_types::total_escrow_value(program) >= total_amount, E_INSUFFICIENT_ESCROW);

        let timestamp = tx_context::epoch(ctx);

        // Withdraw total amount from escrow
        let mut remaining_balance = balance::split(bounty_types::escrow_mut(program), total_amount);

        // Distribute to each recipient
        let recipients = payout_types::recipients(proposal);
        let mut i = 0;
        let len = vector::length(recipients);
        while (i < len) {
            let recipient = vector::borrow(recipients, i);
            let recipient_addr = payout_types::recipient_address(recipient);
            let amount = payout_types::calculate_recipient_amount(proposal, recipient_addr);

            // Split from remaining balance
            let recipient_balance = balance::split(&mut remaining_balance, amount);
            let recipient_coin = coin::from_balance(recipient_balance, ctx);
            transfer::public_transfer(recipient_coin, recipient_addr);

            i = i + 1;
        };

        // Destroy any dust (should be zero)
        balance::destroy_zero(remaining_balance);

        // Update report payout status
        report_types::set_payout_amount(report, total_amount);
        report_types::execute_payout_internal(report, timestamp);

        // Update program statistics
        bounty_types::increment_reports_resolved(program);
        bounty_types::add_payout(program, total_amount);

        // Update report status to PAID
        report_types::set_status(report, report_types::status_paid());

        // Mark proposal as executed
        payout_types::mark_executed(proposal, timestamp);

        // Clear split proposal from report
        report_types::clear_split_proposal(report);

        // Refund submission fee to primary researcher
        let fee = report_types::withdraw_fee(report);
        let fee_coin = coin::from_balance(fee, ctx);
        let primary = payout_types::primary_researcher(proposal);
        transfer::public_transfer(fee_coin, primary);

        // Emit event
        payout_events::emit_split_payout_executed(
            object::uid_to_inner(payout_types::id(proposal)),
            report_id,
            total_amount,
            len,
            timestamp,
        );
    }

    /// Cancel split proposal
    /// Only primary researcher can cancel
    public entry fun cancel_split_proposal(
        proposal: SplitProposal,
        report: &mut BugReport,
        ctx: &TxContext,
    ) {
        // Verify caller is primary researcher
        let caller = tx_context::sender(ctx);
        assert!(caller == payout_types::primary_researcher(&proposal), E_NOT_PRIMARY_RESEARCHER);

        // Verify report matches proposal
        let report_id = object::uid_to_inner(report_types::id(report));
        assert!(payout_types::report_id(&proposal) == report_id, E_INVALID_PROPOSAL);

        // Verify not already executed
        assert!(!payout_types::executed(&proposal), E_ALREADY_EXECUTED);

        let timestamp = tx_context::epoch(ctx);
        let proposal_id = object::uid_to_inner(payout_types::id(&proposal));

        // Clear split proposal from report
        report_types::clear_split_proposal(report);

        // Emit event
        payout_events::emit_split_proposal_cancelled(
            proposal_id,
            report_id,
            caller,
            timestamp,
        );

        // Destroy proposal
        payout_types::destroy(proposal);
    }

    // ======== View Functions ========

    /// Get split proposal details
    /// Returns (total_amount, num_recipients, all_approved, executed)
    public fun get_proposal_status(proposal: &SplitProposal): (u64, u64, bool, bool) {
        let total = payout_types::total_amount(proposal);
        let recipients = payout_types::recipients(proposal);
        let num_recipients = vector::length(recipients);
        let all_approved = payout_types::all_approved(proposal);
        let executed = payout_types::executed(proposal);

        (total, num_recipients, all_approved, executed)
    }

    /// Check if a specific address has approved
    public fun has_approved(proposal: &SplitProposal, addr: address): bool {
        if (!payout_types::has_recipient(proposal, addr)) {
            return false
        };

        let recipients = payout_types::recipients(proposal);
        let mut i = 0;
        let len = vector::length(recipients);
        while (i < len) {
            let recipient = vector::borrow(recipients, i);
            if (payout_types::recipient_address(recipient) == addr) {
                return payout_types::recipient_approved(recipient)
            };
            i = i + 1;
        };

        false
    }

    /// Calculate payout for a specific recipient
    public fun calculate_recipient_payout(proposal: &SplitProposal, addr: address): u64 {
        payout_types::calculate_recipient_amount(proposal, addr)
    }
}
