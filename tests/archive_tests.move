#[test_only]
module suiguard::archive_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object;

    use suiguard::bounty_api;
    use suiguard::bounty_types::BountyProgram;
    use suiguard::bounty_registry::ProgramRegistry;
    use suiguard::bounty_init;
    use suiguard::report_api;
    use suiguard::report_types::{Self, BugReport};
    use suiguard::duplicate_registry::DuplicateRegistry;
    use suiguard::report_init;
    use suiguard::report_response;
    use suiguard::disclosure_api;
    use suiguard::archive_init;
    use suiguard::archive_api;
    use suiguard::archive_types::{Self, ArchiveRegistry, ArchivedReport, VulnerabilityPattern};

    // Test addresses
    const ADMIN: address = @0xAD;
    const PROJECT_OWNER: address = @0xA1;
    const RESEARCHER: address = @0xBEEF;
    const PUBLIC: address = @0xDEAD;

    // Test amounts
    const ONE_SUI: u64 = 1_000_000_000;

    // Valid Walrus blob IDs for testing (32+ bytes)
    const TEST_BLOB_ID: vector<u8> = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const THOUSAND_SUI: u64 = 1_000_000_000_000;
    const MIN_SUBMISSION_FEE: u64 = 10_000_000_000;

    // Severity levels
    const SEVERITY_CRITICAL: u8 = 0;

    // Helper to mint test SUI coins
    fun mint_sui(amount: u64, ctx: &mut sui::tx_context::TxContext): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ctx)
    }

    // Helper to setup bounty program
    fun setup_bounty_program(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            bounty_init::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, ts::ctx(scenario));

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Program",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(scenario)
            );

            ts::return_shared(registry);
        };
    }

    // Helper to create and disclose a bug report
    fun create_and_disclose_report(scenario: &mut Scenario) {
        ts::next_tx(scenario, RESEARCHER);
        {
            report_init::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, ts::ctx(scenario));

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                SEVERITY_CRITICAL,
                0, // category: reentrancy
                TEST_BLOB_ID,
                b"0xe3d7e7a08ec189788f24840d27b02fee45cf3afc0fb579d6e3fd8450c5153d26",
                vector[b"module::function"],
                b"vuln_hash",
                submission_fee,
                ts::ctx(scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Submit fix
        ts::next_tx(scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(scenario, PROJECT_OWNER);

            report_response::submit_fix(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                @0xF1ED,
                ts::ctx(scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Request and approve early disclosure
        ts::next_tx(scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(scenario, PROJECT_OWNER);

            disclosure_api::request_early_disclosure(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                ts::ctx(scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::next_tx(scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(scenario, RESEARCHER);

            disclosure_api::approve_early_disclosure(
                &mut report,
                b"public_seal_policy",
                ts::ctx(scenario)
            );

            ts::return_to_address(RESEARCHER, report);
        };
    }

    #[test]
    fun test_archive_disclosed_report() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_disclose_report(&mut scenario);

        // Initialize archive registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        // Archive the disclosed report
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let mut registry = ts::take_shared<ArchiveRegistry>(&scenario);

            archive_api::archive_report(
                &report,
                &program,
                &mut registry,
                ts::ctx(&mut scenario)
            );

            // Verify registry statistics
            let (total_reports, total_payouts) = archive_api::get_archive_statistics(&registry);
            assert!(total_reports == 1, 0);
            assert!(total_payouts == 0, 1); // No payout executed in this test

            ts::return_shared(registry);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Verify archived report was created
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let archived = ts::take_shared<ArchivedReport>(&scenario);

            assert!(archive_types::archived_severity(&archived) == SEVERITY_CRITICAL, 2);
            assert!(archive_types::cwe_id(&archived) == archive_types::cwe_reentrancy(), 3);
            assert!(archive_types::archived_researcher(&archived) == RESEARCHER, 4);

            ts::return_shared(archived);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 10000)] // E_NOT_DISCLOSED
    fun test_cannot_archive_undisclosed_report() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);

        // Create report but don't disclose
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            report_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, ts::ctx(&mut scenario));

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                SEVERITY_CRITICAL,
                0,
                TEST_BLOB_ID,
                b"0xe3d7e7a08ec189788f24840d27b02fee45cf3afc0fb579d6e3fd8450c5153d26",
                vector[b"module::function"],
                b"vuln_hash",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Initialize archive
        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        // Try to archive undisclosed report - should fail
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let mut registry = ts::take_shared<ArchiveRegistry>(&scenario);

            archive_api::archive_report(
                &report,
                &program,
                &mut registry,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_query_by_cwe_type() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_disclose_report(&mut scenario);

        // Initialize and archive
        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, PUBLIC);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let mut registry = ts::take_shared<ArchiveRegistry>(&scenario);

            archive_api::archive_report(&report, &program, &mut registry, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Query by CWE type
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let registry = ts::take_shared<ArchiveRegistry>(&scenario);

            let cwe_reentrancy = archive_types::cwe_reentrancy();
            let reports = archive_api::query_by_cwe_type(&registry, cwe_reentrancy);

            assert!(std::vector::length(&reports) == 1, 0);

            // Check CWE statistics
            let count = archive_api::get_cwe_statistics(&registry, cwe_reentrancy);
            assert!(count == 1, 1);

            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_query_by_researcher() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_disclose_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, PUBLIC);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let mut registry = ts::take_shared<ArchiveRegistry>(&scenario);

            archive_api::archive_report(&report, &program, &mut registry, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Query by researcher
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let registry = ts::take_shared<ArchiveRegistry>(&scenario);

            let reports = archive_api::query_by_researcher(&registry, RESEARCHER);
            assert!(std::vector::length(&reports) == 1, 0);

            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_query_by_severity() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_disclose_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, PUBLIC);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let mut registry = ts::take_shared<ArchiveRegistry>(&scenario);

            archive_api::archive_report(&report, &program, &mut registry, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Query by severity
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let registry = ts::take_shared<ArchiveRegistry>(&scenario);

            let critical_reports = archive_api::query_by_severity(&registry, SEVERITY_CRITICAL);
            assert!(std::vector::length(&critical_reports) == 1, 0);

            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_register_vulnerability_pattern() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize archive
        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        // Register vulnerability pattern
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<ArchiveRegistry>(&mut scenario);

            let fingerprint = b"reentrancy_pattern_001";
            let cwe_id = archive_types::cwe_reentrancy();
            let description = b"Classic reentrancy vulnerability pattern";
            let code_patterns = vector[b"external_call_.*transfer", b"state_update_after_call"];

            archive_api::register_vulnerability_pattern(
                &mut registry,
                fingerprint,
                cwe_id,
                description,
                code_patterns,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Verify pattern was created
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let pattern = ts::take_shared<VulnerabilityPattern>(&scenario);

            assert!(archive_types::pattern_cwe_id(&pattern) == archive_types::cwe_reentrancy(), 0);
            assert!(archive_types::occurrence_count(&pattern) == 0, 1);

            ts::return_shared(pattern);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_link_report_to_pattern() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_disclose_report(&mut scenario);

        // Initialize archive
        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        // Archive report
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let mut registry = ts::take_shared<ArchiveRegistry>(&scenario);

            archive_api::archive_report(&report, &program, &mut registry, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Register pattern
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<ArchiveRegistry>(&mut scenario);

            archive_api::register_vulnerability_pattern(
                &mut registry,
                b"reentrancy_pattern_001",
                archive_types::cwe_reentrancy(),
                b"Classic reentrancy vulnerability pattern",
                vector[b"external_call_.*transfer"],
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Link report to pattern
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pattern = ts::take_shared<VulnerabilityPattern>(&scenario);
            let mut archived = ts::take_shared<ArchivedReport>(&scenario);

            archive_api::link_to_pattern(
                &mut pattern,
                &mut archived,
                ts::ctx(&mut scenario)
            );

            // Verify pattern updated
            assert!(archive_types::occurrence_count(&pattern) == 1, 0);

            // Verify archived report has related bug
            let related = archive_api::get_related_bugs(&archived);
            assert!(std::vector::length(&related) == 1, 1);

            ts::return_shared(pattern);
            ts::return_shared(archived);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_get_report_summary() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_disclose_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, PUBLIC);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let mut registry = ts::take_shared<ArchiveRegistry>(&scenario);

            archive_api::archive_report(&report, &program, &mut registry, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Get report summary
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let archived = ts::take_shared<ArchivedReport>(&scenario);

            let (severity, cwe_id, payout, disclosed_at, has_fix) = archive_api::get_report_summary(&archived);

            assert!(severity == SEVERITY_CRITICAL, 0);
            assert!(cwe_id == archive_types::cwe_reentrancy(), 1);
            assert!(payout == 0, 2); // No payout executed in test
            // disclosed_at can be 0 if disclosed at epoch 0
            assert!(has_fix, 3); // Fix was submitted

            ts::return_shared(archived);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_cwe_classification() {
        let mut scenario = ts::begin(ADMIN);

        // Test category to CWE mapping
        let cwe_reentrancy = archive_types::category_to_cwe(0);
        assert!(cwe_reentrancy == archive_types::cwe_reentrancy(), 0);

        let cwe_overflow = archive_types::category_to_cwe(1);
        assert!(cwe_overflow == archive_types::cwe_integer_overflow(), 1);

        let cwe_access = archive_types::category_to_cwe(3);
        assert!(cwe_access == archive_types::cwe_access_control(), 2);

        // Test CWE name retrieval
        let name = archive_api::get_cwe_name(cwe_reentrancy);
        assert!(name == b"Improper Enforcement of Behavioral Workflow", 3);

        ts::end(scenario);
    }

    #[test]
    fun test_fingerprint_exists() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_disclose_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            archive_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, PUBLIC);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let mut registry = ts::take_shared<ArchiveRegistry>(&scenario);

            archive_api::archive_report(&report, &program, &mut registry, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Check if fingerprint exists
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let registry = ts::take_shared<ArchiveRegistry>(&scenario);

            let exists = archive_api::fingerprint_exists(&registry, b"vuln_hash");
            assert!(exists, 0);

            let not_exists = archive_api::fingerprint_exists(&registry, b"different_hash");
            assert!(!not_exists, 1);

            ts::return_shared(registry);
        };

        ts::end(scenario);
    }
}
