// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Project Response and Fix Verification Module
/// Enables projects to acknowledge reports, request clarifications,
/// dispute severity assessments, and submit/verify fixes.
module suiguard::report_response {
    use std::option;
    use std::vector;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID};

    use suiguard::report_types::{Self, BugReport};
    use suiguard::bounty_types::{Self, BountyProgram};
    use suiguard::triage_types::{Self, TriageRegistry};
    use suiguard::triage_api;
    use suiguard::report_events;

    // ======== Error Codes ========

    const E_NOT_PROGRAM_OWNER: u64 = 4000;
    const E_ALREADY_ACKNOWLEDGED: u64 = 4001;
    const E_ALREADY_REQUESTED_CLARIFICATION: u64 = 4002;
    const E_ALREADY_DISPUTED: u64 = 4003;
    const E_FIX_ALREADY_SUBMITTED: u64 = 4004;
    const E_FIX_NOT_SUBMITTED: u64 = 4005;
    const E_INVALID_ATTESTATION: u64 = 4006;
    const E_NO_FIX_DETAILS: u64 = 4007;

    // ======== Entry Functions ========

    /// Project acknowledges receipt of vulnerability report
    /// Updates report status and records acknowledgment timestamp
    public entry fun acknowledge_report(
        report: &mut BugReport,
        program: &BountyProgram,
        ctx: &TxContext,
    ) {
        // Verify caller is program owner
        let caller = tx_context::sender(ctx);
        assert!(caller == bounty_types::project_owner(program), E_NOT_PROGRAM_OWNER);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_NOT_PROGRAM_OWNER);

        // Verify not already acknowledged
        assert!(option::is_none(&report_types::acknowledged_at(report)), E_ALREADY_ACKNOWLEDGED);

        let timestamp = tx_context::epoch(ctx);

        // Mark as acknowledged
        report_types::acknowledge_report_internal(report, timestamp);

        // Update status to under review
        report_types::set_status(report, report_types::status_under_review());

        // Emit event
        report_events::emit_report_acknowledged(
            object::uid_to_inner(report_types::id(report)),
            program_id,
            caller,
            timestamp,
        );
    }

    /// Project requests clarification from researcher
    /// Stores clarification message in Walrus blob
    public entry fun request_clarification(
        report: &mut BugReport,
        program: &BountyProgram,
        clarification_message_blob: vector<u8>,
        ctx: &TxContext,
    ) {
        // Verify caller is program owner
        let caller = tx_context::sender(ctx);
        assert!(caller == bounty_types::project_owner(program), E_NOT_PROGRAM_OWNER);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_NOT_PROGRAM_OWNER);

        // Verify clarification not already requested
        assert!(!report_types::clarification_requested(report), E_ALREADY_REQUESTED_CLARIFICATION);

        let timestamp = tx_context::epoch(ctx);

        // Record clarification request
        report_types::request_clarification_internal(report, clarification_message_blob, timestamp);

        // Emit event
        report_events::emit_clarification_requested(
            object::uid_to_inner(report_types::id(report)),
            program_id,
            caller,
            clarification_message_blob,
            timestamp,
        );
    }

    /// Project disputes the severity assessment
    /// Triggers a DAO triage vote for community review
    public entry fun dispute_severity(
        report: &mut BugReport,
        program: &BountyProgram,
        triage_registry: &mut TriageRegistry,
        ctx: &mut TxContext,
    ) {
        // Verify caller is program owner
        let caller = tx_context::sender(ctx);
        assert!(caller == bounty_types::project_owner(program), E_NOT_PROGRAM_OWNER);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_NOT_PROGRAM_OWNER);

        // Verify not already disputed
        assert!(!report_types::severity_disputed(report), E_ALREADY_DISPUTED);

        let report_id = object::uid_to_inner(report_types::id(report));
        let program_id = report_types::program_id(report);
        let timestamp = tx_context::epoch(ctx);

        // Create triage vote for dispute
        // Use standard quorum (10,000 SUI)
        triage_api::create_triage_vote(
            triage_registry,
            report_id,
            program_id,
            10_000_000_000_000, // 10,000 SUI
            ctx,
        );

        // Get the vote ID from registry (it was just created)
        let vote_id = triage_types::get_vote_id_for_report(triage_registry, report_id);

        // Mark report as disputed
        report_types::dispute_severity_internal(report, vote_id, timestamp);

        // Emit event
        report_events::emit_severity_disputed(
            report_id,
            program_id,
            caller,
            vote_id,
            timestamp,
        );
    }

    /// Project submits proof of fix
    /// Records commit hash and/or upgraded package ID
    public entry fun submit_fix(
        report: &mut BugReport,
        program: &BountyProgram,
        fix_commit_hash: vector<u8>,
        fix_package_id: address,
        ctx: &TxContext,
    ) {
        // Verify caller is program owner
        let caller = tx_context::sender(ctx);
        assert!(caller == bounty_types::project_owner(program), E_NOT_PROGRAM_OWNER);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_NOT_PROGRAM_OWNER);

        // Verify fix not already submitted
        assert!(!report_types::fix_submitted(report), E_FIX_ALREADY_SUBMITTED);

        // At least one of commit hash or package ID must be provided
        let has_commit = vector::length(&fix_commit_hash) > 0;
        let has_package = fix_package_id != @0x0;
        assert!(has_commit || has_package, E_NO_FIX_DETAILS);

        let timestamp = tx_context::epoch(ctx);

        let commit_opt = if (has_commit) {
            option::some(fix_commit_hash)
        } else {
            option::none()
        };

        let package_opt = if (has_package) {
            option::some(fix_package_id)
        } else {
            option::none()
        };

        // Record fix submission
        report_types::submit_fix_internal(report, commit_opt, package_opt, timestamp);

        // Emit event
        report_events::emit_fix_submitted(
            object::uid_to_inner(report_types::id(report)),
            program_id,
            caller,
            fix_commit_hash,
            fix_package_id,
            timestamp,
        );
    }

    /// Verify fix using Nautilus TEE
    /// Re-runs PoC in TEE to confirm vulnerability is fixed
    public entry fun verify_fix_with_nautilus(
        report: &mut BugReport,
        program: &BountyProgram,
        attestation_id: ID,
        ctx: &TxContext,
    ) {
        // Verify caller is program owner or researcher
        let caller = tx_context::sender(ctx);
        let is_owner = caller == bounty_types::project_owner(program);
        let is_researcher = caller == report_types::researcher(report);
        assert!(is_owner || is_researcher, E_NOT_PROGRAM_OWNER);

        // Verify report belongs to this program
        let program_id = object::uid_to_inner(bounty_types::id(program));
        assert!(report_types::program_id(report) == program_id, E_NOT_PROGRAM_OWNER);

        // Verify fix was submitted
        assert!(report_types::fix_submitted(report), E_FIX_NOT_SUBMITTED);

        // TODO: Verify attestation exists and is valid
        // For now, we'll trust the attestation_id

        let timestamp = tx_context::epoch(ctx);

        // Mark fix as verified
        report_types::verify_fix_internal(report, option::some(attestation_id), timestamp);

        // Update status to ACCEPTED if verified
        report_types::set_status(report, report_types::status_accepted());

        // Emit event
        report_events::emit_fix_verified(
            object::uid_to_inner(report_types::id(report)),
            program_id,
            caller,
            attestation_id,
            timestamp,
        );
    }
}
