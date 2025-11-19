// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Vulnerability Archive API
/// Permanent storage and querying of disclosed bug reports
module suiguard::archive_api {
    use std::option;
    use sui::object;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::table;
    use sui::vec_set;

    use suiguard::report_types::{Self, BugReport};
    use suiguard::bounty_types::{Self, BountyProgram};
    use suiguard::archive_types::{Self, ArchiveRegistry, ArchivedReport, VulnerabilityPattern};
    use suiguard::archive_events;

    // ======== Error Codes ========

    const E_NOT_DISCLOSED: u64 = 10000;
    const E_ALREADY_ARCHIVED: u64 = 10001;
    const E_NO_REPORTS_FOUND: u64 = 10002;
    const E_INVALID_FINGERPRINT: u64 = 10003;

    // ======== Entry Functions ========

    /// Archive a finalized and disclosed bug report
    /// Can be called by anyone once report is publicly disclosed
    public entry fun archive_report(
        report: &BugReport,
        program: &BountyProgram,
        registry: &mut ArchiveRegistry,
        ctx: &mut TxContext,
    ) {
        // Verify report is publicly disclosed
        assert!(report_types::publicly_disclosed(report), E_NOT_DISCLOSED);

        let current_epoch = tx_context::epoch(ctx);
        let report_id = object::uid_to_inner(report_types::id(report));
        let program_id = object::uid_to_inner(bounty_types::id(program));

        // Verify report belongs to this program
        assert!(report_types::program_id(report) == program_id, E_NOT_DISCLOSED);

        // Extract report data
        let researcher = report_types::researcher(report);
        let severity = report_types::severity(report);
        let category = report_types::category(report);
        let cwe_id = archive_types::category_to_cwe(category);
        let walrus_blob_id = *report_types::walrus_blob_id(report);

        // Get public seal policy
        let public_seal_policy_opt = report_types::public_seal_policy(report);
        let public_seal_policy = if (option::is_some(&public_seal_policy_opt)) {
            *option::borrow(&public_seal_policy_opt)
        } else {
            b"" // Empty if not available
        };

        // Extract affected targets
        let affected_targets = report_types::affected_targets(report);
        let affected_modules = *affected_targets;
        let affected_functions = std::vector::empty<vector<u8>>();

        // Generate vulnerability fingerprint
        let vulnerability_hash = *report_types::vulnerability_hash(report);
        let vulnerability_fingerprint = vulnerability_hash;

        let payout_amount = report_types::payout_amount(report);
        let submitted_at = report_types::submitted_at(report);

        let disclosed_at_opt = report_types::disclosed_at(report);
        let disclosed_at = if (option::is_some(&disclosed_at_opt)) {
            *option::borrow(&disclosed_at_opt)
        } else {
            current_epoch
        };

        let fix_commit_hash = if (report_types::fix_submitted(report)) {
            report_types::fix_commit_hash(report)
        } else {
            option::none()
        };

        let fix_package_id = if (report_types::fix_submitted(report)) {
            report_types::fix_package_id(report)
        } else {
            option::none()
        };

        // Create archived report
        let archived = archive_types::new_archived_report(
            report_id,
            program_id,
            *bounty_types::name(program),
            researcher,
            severity,
            cwe_id,
            walrus_blob_id,
            public_seal_policy,
            affected_modules,
            affected_functions,
            vulnerability_fingerprint,
            payout_amount,
            submitted_at,
            disclosed_at,
            current_epoch,
            fix_commit_hash,
            fix_package_id,
            ctx,
        );

        let archived_id = object::uid_to_inner(archive_types::archived_report_id(&archived));

        // Index in registry
        archive_types::index_archived_report(
            registry,
            archived_id,
            program_id,
            severity,
            cwe_id,
            researcher,
            vulnerability_fingerprint,
            payout_amount,
        );

        // Emit event
        archive_events::emit_report_archived(
            archived_id,
            report_id,
            program_id,
            researcher,
            severity,
            cwe_id,
            payout_amount,
            current_epoch,
        );

        // Transfer to permanent storage (public shared or frozen)
        transfer::public_share_object(archived);
    }

    /// Register a vulnerability pattern (ML-generated, off-chain analysis)
    /// This would typically be called by an authorized pattern analyzer
    public entry fun register_vulnerability_pattern(
        registry: &mut ArchiveRegistry,
        fingerprint: vector<u8>,
        cwe_id: u16,
        description: vector<u8>,
        code_patterns: vector<vector<u8>>,
        ctx: &mut TxContext,
    ) {
        let current_epoch = tx_context::epoch(ctx);

        let pattern = archive_types::new_vulnerability_pattern(
            fingerprint,
            cwe_id,
            description,
            code_patterns,
            current_epoch,
            ctx,
        );

        let pattern_id = object::uid_to_inner(archive_types::pattern_id(&pattern));

        // Emit event
        archive_events::emit_vulnerability_pattern_identified(
            pattern_id,
            fingerprint,
            cwe_id,
            0, // Initial occurrence count
            current_epoch,
        );

        // Share pattern for public access
        transfer::public_share_object(pattern);
    }

    /// Link report to vulnerability pattern
    /// Can be called by pattern analyzer when match is found
    public entry fun link_to_pattern(
        pattern: &mut VulnerabilityPattern,
        archived_report: &mut ArchivedReport,
        ctx: &TxContext,
    ) {
        let current_epoch = tx_context::epoch(ctx);
        let report_id = object::uid_to_inner(archive_types::archived_report_id(archived_report));
        let pattern_id = object::uid_to_inner(archive_types::pattern_id(pattern));

        // Add report to pattern
        archive_types::add_report_to_pattern(pattern, report_id, current_epoch);

        // Add pattern reference to report as related bug
        archive_types::add_related_bug(archived_report, pattern_id);

        // Emit event
        archive_events::emit_pattern_match_found(
            pattern_id,
            report_id,
            archive_types::pattern_cwe_id(pattern),
            current_epoch,
        );
    }

    /// Alert about similar vulnerability in another program
    /// Called by pattern analyzer when detecting potential vulnerability
    public entry fun alert_similar_vulnerability(
        target_program: &BountyProgram,
        reference_report: &ArchivedReport,
        similarity_fingerprint: vector<u8>,
        ctx: &TxContext,
    ) {
        let current_epoch = tx_context::epoch(ctx);
        let target_program_id = object::uid_to_inner(bounty_types::id(target_program));
        let reference_report_id = object::uid_to_inner(archive_types::archived_report_id(reference_report));
        let cwe_id = archive_types::cwe_id(reference_report);

        // Emit alert event
        archive_events::emit_similar_vulnerability_alert(
            target_program_id,
            reference_report_id,
            similarity_fingerprint,
            cwe_id,
            current_epoch,
        );
    }

    // ======== View Functions ========

    /// Query archived reports by CWE type
    /// Returns vector of report IDs
    public fun query_by_cwe_type(registry: &ArchiveRegistry, cwe_id: u16): vector<sui::object::ID> {
        let cwe_index = archive_types::cwe_index(registry);

        if (!table::contains(cwe_index, cwe_id)) {
            return std::vector::empty()
        };

        let report_set = table::borrow(cwe_index, cwe_id);
        vec_set::into_keys(*report_set)
    }

    /// Query archived reports by program
    public fun query_by_program(registry: &ArchiveRegistry, program_id: sui::object::ID): vector<sui::object::ID> {
        let program_index = archive_types::program_index(registry);

        if (!table::contains(program_index, program_id)) {
            return std::vector::empty()
        };

        let report_set = table::borrow(program_index, program_id);
        vec_set::into_keys(*report_set)
    }

    /// Query archived reports by severity
    public fun query_by_severity(registry: &ArchiveRegistry, severity: u8): vector<sui::object::ID> {
        let severity_index = archive_types::severity_index(registry);

        if (!table::contains(severity_index, severity)) {
            return std::vector::empty()
        };

        let report_set = table::borrow(severity_index, severity);
        vec_set::into_keys(*report_set)
    }

    /// Query archived reports by researcher
    public fun query_by_researcher(registry: &ArchiveRegistry, researcher: address): vector<sui::object::ID> {
        let researcher_index = archive_types::researcher_index(registry);

        if (!table::contains(researcher_index, researcher)) {
            return std::vector::empty()
        };

        let report_set = table::borrow(researcher_index, researcher);
        vec_set::into_keys(*report_set)
    }

    /// Get related bugs (similar vulnerability patterns)
    public fun get_related_bugs(archived_report: &ArchivedReport): vector<sui::object::ID> {
        let related_set = archive_types::related_bugs(archived_report);
        vec_set::into_keys(*related_set)
    }

    /// Query by vulnerability fingerprint
    /// Returns reports with matching fingerprints
    public fun query_by_fingerprint(registry: &ArchiveRegistry, fingerprint: vector<u8>): vector<sui::object::ID> {
        let fingerprint_index = archive_types::fingerprint_index(registry);

        if (!table::contains(fingerprint_index, fingerprint)) {
            return std::vector::empty()
        };

        let report_set = table::borrow(fingerprint_index, fingerprint);
        vec_set::into_keys(*report_set)
    }

    /// Get statistics for a CWE type
    /// Returns total count of reports for that CWE
    public fun get_cwe_statistics(registry: &ArchiveRegistry, cwe_id: u16): u64 {
        let cwe_stats = archive_types::cwe_statistics(registry);

        if (!table::contains(cwe_stats, cwe_id)) {
            return 0
        };

        *table::borrow(cwe_stats, cwe_id)
    }

    /// Get global archive statistics
    /// Returns (total_reports, total_payouts)
    public fun get_archive_statistics(registry: &ArchiveRegistry): (u64, u64) {
        let total_reports = archive_types::total_reports(registry);
        let total_payouts = archive_types::total_payouts(registry);

        (total_reports, total_payouts)
    }

    /// Get archived report summary
    /// Returns (severity, cwe_id, payout_amount, disclosed_at, has_fix)
    public fun get_report_summary(archived_report: &ArchivedReport): (u8, u16, u64, u64, bool) {
        let severity = archive_types::archived_severity(archived_report);
        let cwe_id = archive_types::cwe_id(archived_report);
        let payout = archive_types::archived_payout_amount(archived_report);
        let disclosed_at = archive_types::archived_disclosed_at(archived_report);
        let has_fix = option::is_some(&archive_types::fix_commit_hash(archived_report));

        (severity, cwe_id, payout, disclosed_at, has_fix)
    }

    /// Check if fingerprint exists in archive
    /// Returns true if similar vulnerability pattern exists
    public fun fingerprint_exists(registry: &ArchiveRegistry, fingerprint: vector<u8>): bool {
        let fingerprint_index = archive_types::fingerprint_index(registry);
        table::contains(fingerprint_index, fingerprint)
    }

    /// Get CWE name by ID
    public fun get_cwe_name(cwe_id: u16): vector<u8> {
        archive_types::get_cwe_name(cwe_id)
    }
}
