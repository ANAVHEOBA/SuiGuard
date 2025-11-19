/// Bug Report Events
/// Events emitted during report lifecycle
module suiguard::report_events {
    use sui::object::ID;
    use sui::event;

    /// Emitted when a new bug report is submitted
    public struct ReportSubmitted has copy, drop {
        report_id: ID,
        program_id: ID,
        researcher: address,
        severity: u8,
        category: u8,
        walrus_blob_id: vector<u8>,
        submission_fee: u64,
        submitted_at: u64,
    }

    /// Emitted when a report is withdrawn by researcher
    public struct ReportWithdrawn has copy, drop {
        report_id: ID,
        program_id: ID,
        researcher: address,
        fee_refunded: u64,
    }

    /// Emitted when a report is marked as duplicate
    public struct ReportMarkedDuplicate has copy, drop {
        report_id: ID,
        program_id: ID,
        original_report_id: ID,
        researcher: address,
    }

    /// Emitted when a report status changes
    public struct ReportStatusChanged has copy, drop {
        report_id: ID,
        program_id: ID,
        old_status: u8,
        new_status: u8,
        changed_at: u64,
    }

    /// Emitted when an attestation is linked to a report
    public struct AttestationLinked has copy, drop {
        report_id: ID,
        attestation_id: ID,
        researcher: address,
    }

    // ========== Project Response Events ==========

    /// Emitted when a project acknowledges a bug report
    public struct ReportAcknowledged has copy, drop {
        report_id: ID,
        program_id: ID,
        project_owner: address,
        acknowledged_at: u64,
    }

    /// Emitted when a project requests clarification from researcher
    public struct ClarificationRequested has copy, drop {
        report_id: ID,
        program_id: ID,
        project_owner: address,
        clarification_blob: vector<u8>,
        requested_at: u64,
    }

    /// Emitted when a project disputes severity assessment
    public struct SeverityDisputed has copy, drop {
        report_id: ID,
        program_id: ID,
        project_owner: address,
        triage_vote_id: ID,
        disputed_at: u64,
    }

    /// Emitted when a project submits a fix
    public struct FixSubmitted has copy, drop {
        report_id: ID,
        program_id: ID,
        project_owner: address,
        fix_commit_hash: vector<u8>,
        fix_package_id: address,
        submitted_at: u64,
    }

    /// Emitted when a fix is verified
    public struct FixVerified has copy, drop {
        report_id: ID,
        program_id: ID,
        verifier: address,
        attestation_id: ID,
        verified_at: u64,
    }

    // ========== Event Emission Functions ==========

    public(package) fun emit_report_submitted(
        report_id: ID,
        program_id: ID,
        researcher: address,
        severity: u8,
        category: u8,
        walrus_blob_id: vector<u8>,
        submission_fee: u64,
        submitted_at: u64,
    ) {
        event::emit(ReportSubmitted {
            report_id,
            program_id,
            researcher,
            severity,
            category,
            walrus_blob_id,
            submission_fee,
            submitted_at,
        });
    }

    public(package) fun emit_report_withdrawn(
        report_id: ID,
        program_id: ID,
        researcher: address,
        fee_refunded: u64,
    ) {
        event::emit(ReportWithdrawn {
            report_id,
            program_id,
            researcher,
            fee_refunded,
        });
    }

    public(package) fun emit_report_marked_duplicate(
        report_id: ID,
        program_id: ID,
        original_report_id: ID,
        researcher: address,
    ) {
        event::emit(ReportMarkedDuplicate {
            report_id,
            program_id,
            original_report_id,
            researcher,
        });
    }

    public(package) fun emit_report_status_changed(
        report_id: ID,
        program_id: ID,
        old_status: u8,
        new_status: u8,
        changed_at: u64,
    ) {
        event::emit(ReportStatusChanged {
            report_id,
            program_id,
            old_status,
            new_status,
            changed_at,
        });
    }

    public(package) fun emit_attestation_linked(
        report_id: ID,
        attestation_id: ID,
        researcher: address,
    ) {
        event::emit(AttestationLinked {
            report_id,
            attestation_id,
            researcher,
        });
    }

    // ========== Project Response Event Emission Functions ==========

    public(package) fun emit_report_acknowledged(
        report_id: ID,
        program_id: ID,
        project_owner: address,
        acknowledged_at: u64,
    ) {
        event::emit(ReportAcknowledged {
            report_id,
            program_id,
            project_owner,
            acknowledged_at,
        });
    }

    public(package) fun emit_clarification_requested(
        report_id: ID,
        program_id: ID,
        project_owner: address,
        clarification_blob: vector<u8>,
        requested_at: u64,
    ) {
        event::emit(ClarificationRequested {
            report_id,
            program_id,
            project_owner,
            clarification_blob,
            requested_at,
        });
    }

    public(package) fun emit_severity_disputed(
        report_id: ID,
        program_id: ID,
        project_owner: address,
        triage_vote_id: ID,
        disputed_at: u64,
    ) {
        event::emit(SeverityDisputed {
            report_id,
            program_id,
            project_owner,
            triage_vote_id,
            disputed_at,
        });
    }

    public(package) fun emit_fix_submitted(
        report_id: ID,
        program_id: ID,
        project_owner: address,
        fix_commit_hash: vector<u8>,
        fix_package_id: address,
        submitted_at: u64,
    ) {
        event::emit(FixSubmitted {
            report_id,
            program_id,
            project_owner,
            fix_commit_hash,
            fix_package_id,
            submitted_at,
        });
    }

    public(package) fun emit_fix_verified(
        report_id: ID,
        program_id: ID,
        verifier: address,
        attestation_id: ID,
        verified_at: u64,
    ) {
        event::emit(FixVerified {
            report_id,
            program_id,
            verifier,
            attestation_id,
            verified_at,
        });
    }
}
