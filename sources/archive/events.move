// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Archive System Events
module suiguard::archive_events {
    use sui::object::ID;
    use sui::event;

    /// Emitted when a report is archived
    public struct ReportArchived has copy, drop {
        archived_id: ID,
        report_id: ID,
        program_id: ID,
        researcher: address,
        severity: u8,
        cwe_id: u16,
        payout_amount: u64,
        archived_at: u64,
    }

    /// Emitted when related bugs are linked
    public struct RelatedBugsLinked has copy, drop {
        report_id: ID,
        related_report_ids: vector<ID>,
        linked_at: u64,
    }

    /// Emitted when a vulnerability pattern is identified
    public struct VulnerabilityPatternIdentified has copy, drop {
        pattern_id: ID,
        fingerprint: vector<u8>,
        cwe_id: u16,
        occurrence_count: u64,
        identified_at: u64,
    }

    /// Emitted when a pattern match is found
    public struct PatternMatchFound has copy, drop {
        pattern_id: ID,
        report_id: ID,
        cwe_id: u16,
        matched_at: u64,
    }

    /// Emitted when similar vulnerability alert is triggered
    public struct SimilarVulnerabilityAlert has copy, drop {
        target_program_id: ID,
        reference_report_id: ID,
        similarity_fingerprint: vector<u8>,
        cwe_id: u16,
        alerted_at: u64,
    }

    // ========== Event Emission Functions ==========

    public(package) fun emit_report_archived(
        archived_id: ID,
        report_id: ID,
        program_id: ID,
        researcher: address,
        severity: u8,
        cwe_id: u16,
        payout_amount: u64,
        archived_at: u64,
    ) {
        event::emit(ReportArchived {
            archived_id,
            report_id,
            program_id,
            researcher,
            severity,
            cwe_id,
            payout_amount,
            archived_at,
        });
    }

    public(package) fun emit_related_bugs_linked(
        report_id: ID,
        related_report_ids: vector<ID>,
        linked_at: u64,
    ) {
        event::emit(RelatedBugsLinked {
            report_id,
            related_report_ids,
            linked_at,
        });
    }

    public(package) fun emit_vulnerability_pattern_identified(
        pattern_id: ID,
        fingerprint: vector<u8>,
        cwe_id: u16,
        occurrence_count: u64,
        identified_at: u64,
    ) {
        event::emit(VulnerabilityPatternIdentified {
            pattern_id,
            fingerprint,
            cwe_id,
            occurrence_count,
            identified_at,
        });
    }

    public(package) fun emit_pattern_match_found(
        pattern_id: ID,
        report_id: ID,
        cwe_id: u16,
        matched_at: u64,
    ) {
        event::emit(PatternMatchFound {
            pattern_id,
            report_id,
            cwe_id,
            matched_at,
        });
    }

    public(package) fun emit_similar_vulnerability_alert(
        target_program_id: ID,
        reference_report_id: ID,
        similarity_fingerprint: vector<u8>,
        cwe_id: u16,
        alerted_at: u64,
    ) {
        event::emit(SimilarVulnerabilityAlert {
            target_program_id,
            reference_report_id,
            similarity_fingerprint,
            cwe_id,
            alerted_at,
        });
    }
}
