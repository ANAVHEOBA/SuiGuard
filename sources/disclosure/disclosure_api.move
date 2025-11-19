// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Time-Locked Disclosure System
/// Handles 90-day auto-disclosure and early disclosure for fixed bugs
module suiguard::disclosure_api {
    use sui::object;
    use sui::tx_context::{Self, TxContext};

    use suiguard::report_types::{Self, BugReport};
    use suiguard::bounty_types::{Self, BountyProgram};
    use suiguard::disclosure_events;

    // ======== Error Codes ========

    const E_NOT_RESEARCHER: u64 = 9000;
    const E_NOT_PROJECT_OWNER: u64 = 9001;
    const E_ALREADY_DISCLOSED: u64 = 9002;
    const E_DEADLINE_NOT_REACHED: u64 = 9003;
    const E_FIX_NOT_SUBMITTED: u64 = 9004;
    const E_EARLY_DISCLOSURE_NOT_REQUESTED: u64 = 9005;
    const E_ALREADY_APPROVED: u64 = 9006;
    const E_EARLY_DISCLOSURE_NOT_APPROVED: u64 = 9007;

    // ======== View Functions ========

    /// Check disclosure status and eligibility
    /// Returns (can_disclose, reason, time_remaining)
    /// Reason codes:
    /// 0 = Can disclose (deadline reached)
    /// 1 = Can disclose early (fix verified and approved)
    /// 2 = Cannot disclose (deadline not reached)
    /// 3 = Cannot disclose (early disclosure not approved)
    /// 4 = Already disclosed
    public fun check_disclosure_status(
        report: &BugReport,
        current_epoch: u64,
    ): (bool, u8, u64) {
        // Check if already disclosed
        if (report_types::publicly_disclosed(report)) {
            return (false, 4, 0)
        };

        let deadline = report_types::disclosure_deadline(report);

        // Check if deadline has been reached (90 days)
        if (current_epoch >= deadline) {
            return (true, 0, 0)
        };

        // Check if early disclosure is approved
        if (report_types::early_disclosure_approved(report)) {
            return (true, 1, 0)
        };

        // Calculate time remaining until disclosure
        let time_remaining = deadline - current_epoch;

        // Check if early disclosure is possible but not yet approved
        if (report_types::early_disclosure_requested(report)) {
            return (false, 3, time_remaining)
        };

        // Deadline not reached yet
        (false, 2, time_remaining)
    }

    /// Get disclosure status details
    /// Returns (deadline, is_disclosed, disclosed_at, early_requested, early_approved)
    public fun get_disclosure_details(report: &BugReport): (u64, bool, u64, bool, bool) {
        let deadline = report_types::disclosure_deadline(report);
        let is_disclosed = report_types::publicly_disclosed(report);
        let disclosed_at = if (is_disclosed) {
            let option_time = report_types::disclosed_at(report);
            *std::option::borrow(&option_time)
        } else {
            0
        };
        let early_requested = report_types::early_disclosure_requested(report);
        let early_approved = report_types::early_disclosure_approved(report);

        (deadline, is_disclosed, disclosed_at, early_requested, early_approved)
    }

    // ======== Entry Functions ========

    /// Trigger public disclosure after 90 days
    /// Can be called by anyone once deadline is reached
    public entry fun trigger_public_disclosure(
        report: &mut BugReport,
        public_seal_policy_blob: vector<u8>,
        ctx: &TxContext,
    ) {
        // Check if already disclosed
        assert!(!report_types::publicly_disclosed(report), E_ALREADY_DISCLOSED);

        let current_epoch = tx_context::epoch(ctx);
        let deadline = report_types::disclosure_deadline(report);

        // Verify deadline has been reached
        assert!(current_epoch >= deadline, E_DEADLINE_NOT_REACHED);

        let report_id = object::uid_to_inner(report_types::id(report));
        let program_id = report_types::program_id(report);
        let researcher = report_types::researcher(report);

        // Emit deadline reached event
        disclosure_events::emit_disclosure_deadline_reached(
            report_id,
            program_id,
            researcher,
            deadline,
            current_epoch,
        );

        // Mark as publicly disclosed
        report_types::trigger_disclosure_internal(
            report,
            public_seal_policy_blob,
            current_epoch,
        );

        // Emit disclosure event
        disclosure_events::emit_report_publicly_disclosed(
            report_id,
            program_id,
            researcher,
            public_seal_policy_blob,
            current_epoch,
            false, // not early disclosure
        );
    }

    /// Project requests early disclosure after fix is deployed
    /// Requires: fix must be submitted and optionally verified
    public entry fun request_early_disclosure(
        report: &mut BugReport,
        program: &BountyProgram,
        fix_commit_hash: vector<u8>,
        ctx: &TxContext,
    ) {
        // Verify caller is project owner
        let caller = tx_context::sender(ctx);
        assert!(caller == bounty_types::project_owner(program), E_NOT_PROJECT_OWNER);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_NOT_PROJECT_OWNER);

        // Verify not already disclosed
        assert!(!report_types::publicly_disclosed(report), E_ALREADY_DISCLOSED);

        // Verify fix has been submitted
        assert!(report_types::fix_submitted(report), E_FIX_NOT_SUBMITTED);

        let current_epoch = tx_context::epoch(ctx);
        let report_id = object::uid_to_inner(report_types::id(report));

        // Mark early disclosure as requested
        report_types::request_early_disclosure_internal(report, current_epoch);

        // Emit event
        disclosure_events::emit_early_disclosure_requested(
            report_id,
            program_id,
            caller,
            fix_commit_hash,
            current_epoch,
        );
    }

    /// Researcher approves early disclosure
    /// Allows report to be made public before 90-day deadline
    public entry fun approve_early_disclosure(
        report: &mut BugReport,
        public_seal_policy_blob: vector<u8>,
        ctx: &TxContext,
    ) {
        // Verify caller is the researcher
        let caller = tx_context::sender(ctx);
        assert!(caller == report_types::researcher(report), E_NOT_RESEARCHER);

        // Verify early disclosure was requested
        assert!(
            report_types::early_disclosure_requested(report),
            E_EARLY_DISCLOSURE_NOT_REQUESTED
        );

        // Verify not already approved
        assert!(!report_types::early_disclosure_approved(report), E_ALREADY_APPROVED);

        // Verify not already disclosed
        assert!(!report_types::publicly_disclosed(report), E_ALREADY_DISCLOSED);

        let current_epoch = tx_context::epoch(ctx);
        let report_id = object::uid_to_inner(report_types::id(report));
        let program_id = report_types::program_id(report);

        // Mark as approved
        report_types::approve_early_disclosure_internal(report);

        // Emit approval event
        disclosure_events::emit_early_disclosure_approved(
            report_id,
            program_id,
            caller,
            current_epoch,
        );

        // Automatically disclose
        report_types::trigger_disclosure_internal(
            report,
            public_seal_policy_blob,
            current_epoch,
        );

        // Emit disclosure event
        disclosure_events::emit_report_publicly_disclosed(
            report_id,
            program_id,
            caller,
            public_seal_policy_blob,
            current_epoch,
            true, // early disclosure
        );
    }

    /// Researcher rejects early disclosure request
    /// Report will remain private until 90-day deadline
    public entry fun reject_early_disclosure(
        report: &mut BugReport,
        ctx: &TxContext,
    ) {
        // Verify caller is the researcher
        let caller = tx_context::sender(ctx);
        assert!(caller == report_types::researcher(report), E_NOT_RESEARCHER);

        // Verify early disclosure was requested
        assert!(
            report_types::early_disclosure_requested(report),
            E_EARLY_DISCLOSURE_NOT_REQUESTED
        );

        // Verify not already approved
        assert!(!report_types::early_disclosure_approved(report), E_ALREADY_APPROVED);

        let current_epoch = tx_context::epoch(ctx);
        let report_id = object::uid_to_inner(report_types::id(report));
        let program_id = report_types::program_id(report);

        // Emit rejection event (request remains, but researcher declined)
        disclosure_events::emit_early_disclosure_rejected(
            report_id,
            program_id,
            caller,
            current_epoch,
        );
    }

    // ======== Helper Functions ========

    /// Check if report is eligible for public disclosure
    public fun is_disclosure_eligible(report: &BugReport, current_epoch: u64): bool {
        if (report_types::publicly_disclosed(report)) {
            return false
        };

        // Can disclose if deadline reached OR early disclosure approved
        let deadline = report_types::disclosure_deadline(report);
        current_epoch >= deadline || report_types::early_disclosure_approved(report)
    }

    /// Get time until disclosure deadline
    public fun time_until_disclosure(report: &BugReport, current_epoch: u64): u64 {
        let deadline = report_types::disclosure_deadline(report);
        if (current_epoch >= deadline) {
            0
        } else {
            deadline - current_epoch
        }
    }
}
