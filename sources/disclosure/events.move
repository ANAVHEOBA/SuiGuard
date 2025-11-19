// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Disclosure System Events
module suiguard::disclosure_events {
    use sui::object::ID;
    use sui::event;

    /// Emitted when disclosure deadline is reached
    public struct DisclosureDeadlineReached has copy, drop {
        report_id: ID,
        program_id: ID,
        researcher: address,
        deadline: u64,
        timestamp: u64,
    }

    /// Emitted when report is publicly disclosed
    public struct ReportPubliclyDisclosed has copy, drop {
        report_id: ID,
        program_id: ID,
        researcher: address,
        public_seal_policy: vector<u8>,
        disclosed_at: u64,
        is_early: bool, // true if disclosed before 90 days
    }

    /// Emitted when project requests early disclosure
    public struct EarlyDisclosureRequested has copy, drop {
        report_id: ID,
        program_id: ID,
        project_owner: address,
        fix_commit_hash: vector<u8>,
        requested_at: u64,
    }

    /// Emitted when researcher approves early disclosure
    public struct EarlyDisclosureApproved has copy, drop {
        report_id: ID,
        program_id: ID,
        researcher: address,
        approved_at: u64,
    }

    /// Emitted when early disclosure request is rejected
    public struct EarlyDisclosureRejected has copy, drop {
        report_id: ID,
        program_id: ID,
        researcher: address,
        rejected_at: u64,
    }

    // ========== Event Emission Functions ==========

    public(package) fun emit_disclosure_deadline_reached(
        report_id: ID,
        program_id: ID,
        researcher: address,
        deadline: u64,
        timestamp: u64,
    ) {
        event::emit(DisclosureDeadlineReached {
            report_id,
            program_id,
            researcher,
            deadline,
            timestamp,
        });
    }

    public(package) fun emit_report_publicly_disclosed(
        report_id: ID,
        program_id: ID,
        researcher: address,
        public_seal_policy: vector<u8>,
        disclosed_at: u64,
        is_early: bool,
    ) {
        event::emit(ReportPubliclyDisclosed {
            report_id,
            program_id,
            researcher,
            public_seal_policy,
            disclosed_at,
            is_early,
        });
    }

    public(package) fun emit_early_disclosure_requested(
        report_id: ID,
        program_id: ID,
        project_owner: address,
        fix_commit_hash: vector<u8>,
        requested_at: u64,
    ) {
        event::emit(EarlyDisclosureRequested {
            report_id,
            program_id,
            project_owner,
            fix_commit_hash,
            requested_at,
        });
    }

    public(package) fun emit_early_disclosure_approved(
        report_id: ID,
        program_id: ID,
        researcher: address,
        approved_at: u64,
    ) {
        event::emit(EarlyDisclosureApproved {
            report_id,
            program_id,
            researcher,
            approved_at,
        });
    }

    public(package) fun emit_early_disclosure_rejected(
        report_id: ID,
        program_id: ID,
        researcher: address,
        rejected_at: u64,
    ) {
        event::emit(EarlyDisclosureRejected {
            report_id,
            program_id,
            researcher,
            rejected_at,
        });
    }
}
