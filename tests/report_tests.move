#[test_only]
module suiguard::report_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object::{Self, ID};
    use std::option;
    use suiguard::report_api;
    use suiguard::report_types::{Self, BugReport};
    use suiguard::duplicate_registry::{Self, DuplicateRegistry};
    use suiguard::report_init;
    use suiguard::bounty_init;
    use suiguard::bounty_api;
    use suiguard::bounty_types::BountyProgram;
    use suiguard::bounty_registry::ProgramRegistry;

    // Test addresses
    const ADMIN: address = @0xAD;
    const PROJECT_OWNER: address = @0xA1;
    const RESEARCHER: address = @0xB1;
    const RESEARCHER2: address = @0xB2;

    // Test amounts (in MIST - 1 SUI = 1_000_000_000 MIST)
    const ONE_SUI: u64 = 1_000_000_000;

    // Valid Walrus blob IDs for testing (32+ bytes)
    const TEST_BLOB_ID: vector<u8> = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const THOUSAND_SUI: u64 = 1_000_000_000_000;
    const MIN_SUBMISSION_FEE: u64 = 10_000_000_000; // 10 SUI

    // Helper function to create test scenario with registries
    fun setup_test(): Scenario {
        let mut scenario = ts::begin(ADMIN);
        // Initialize both registries
        bounty_init::init_for_testing(ts::ctx(&mut scenario));
        report_init::init_for_testing(ts::ctx(&mut scenario));
        scenario
    }

    // Helper to mint test SUI coins
    fun mint_sui(amount: u64, scenario: &mut Scenario): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    // Helper to create a test bounty program
    fun create_test_program(scenario: &mut Scenario) {
        ts::next_tx(scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, scenario); // 100,000 SUI

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bug Bounty",
                b"Test bounty program description",
                escrow,
                50_000 * ONE_SUI,  // critical
                20_000 * ONE_SUI,  // high
                5_000 * ONE_SUI,   // medium
                1_000 * ONE_SUI,   // low
                100 * ONE_SUI,     // informational
                TEST_BLOB_ID,
                90,
                ts::ctx(scenario)
            );

            ts::return_shared(registry);
        };
    }

    // ========== Test: Successful Bug Report Submission ==========

    #[test]
    fun test_submit_bug_report_success() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        // Researcher submits bug report
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                0, // severity: Critical
                3, // category: Access Control
                TEST_BLOB_ID,
                b"0xe3d7e7a08ec189788f24840d27b02fee45cf3afc0fb579d6e3fd8450c5153d26", // seal_policy_id as vector<u8>
                vector[b"module::vulnerable_function"],
                b"vulnerability_hash_123",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Verify report was created
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let report = ts::take_from_sender<BugReport>(&scenario);

            assert!(report_types::researcher(&report) == RESEARCHER, 0);
            assert!(report_types::severity(&report) == 0, 1);
            assert!(report_types::category(&report) == 3, 2);
            assert!(report_types::is_submitted(&report), 3);
            assert!(report_types::submission_fee_value(&report) == MIN_SUBMISSION_FEE, 4);

            ts::return_to_sender(&scenario, report);
        };

        ts::end(scenario);
    }

    // ========== Test: Duplicate Detection ==========

    #[test]
    fun test_duplicate_detection() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        // First researcher submits bug report
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                0, // Critical
                3, // Access Control
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"module::function"],
                b"same_vulnerability_hash",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Get original report ID
        ts::next_tx(&mut scenario, RESEARCHER);
        let original_report = ts::take_from_sender<BugReport>(&scenario);
        let original_id = object::uid_to_inner(report_types::id(&original_report));

        // Register it as accepted (not duplicate)
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);

            report_api::register_accepted_report(
                &mut dup_registry,
                &original_report
            );

            ts::return_shared(dup_registry);
        };

        ts::return_to_sender(&scenario, original_report);

        // Second researcher tries to submit same vulnerability
        ts::next_tx(&mut scenario, RESEARCHER2);
        {
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);

            // Check for duplicate
            let duplicate_check = report_api::check_duplicate(
                &dup_registry,
                b"same_vulnerability_hash"
            );

            assert!(option::is_some(&duplicate_check), 0);
            assert!(option::destroy_some(duplicate_check) == original_id, 1);

            ts::return_shared(dup_registry);
        };

        ts::end(scenario);
    }

    // ========== Test: Report Withdrawal ==========

    #[test]
    fun test_withdraw_report_success() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        // Submit report
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                1, // High
                2, // Logic Error
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"module::test"],
                b"withdraw_test_hash",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Withdraw report
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let report = ts::take_from_sender<BugReport>(&scenario);
            let mut dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);

            let can_withdraw = report_api::can_withdraw(&report);
            assert!(can_withdraw, 0);

            report_api::withdraw_report(
                report,
                &mut dup_registry,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
        };

        // Verify refund was received
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let refund = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&refund) == MIN_SUBMISSION_FEE, 1);
            ts::return_to_sender(&scenario, refund);
        };

        ts::end(scenario);
    }

    // ========== Test: Mark as Duplicate ==========

    #[test]
    fun test_mark_as_duplicate() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        // Submit original report
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                0, // Critical
                0, // Reentrancy
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"contract::reentrancy"],
                b"reentrancy_vuln_hash",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::next_tx(&mut scenario, RESEARCHER);
        let original_report = ts::take_from_sender<BugReport>(&scenario);
        let original_id = object::uid_to_inner(report_types::id(&original_report));

        // Register original as accepted
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            report_api::register_accepted_report(
                &mut dup_registry,
                &original_report
            );
            ts::return_shared(dup_registry);
        };

        ts::return_to_sender(&scenario, original_report);

        // Submit duplicate report
        ts::next_tx(&mut scenario, RESEARCHER2);
        {
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                0, // Critical
                0, // Reentrancy
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"contract::reentrancy"],
                b"different_hash_for_dup", // Different hash since it's a separate submission
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::next_tx(&mut scenario, RESEARCHER2);
        let mut duplicate_report = ts::take_from_sender<BugReport>(&scenario);

        // Mark as duplicate
        ts::next_tx(&mut scenario, RESEARCHER2);
        {
            let mut dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);

            report_api::mark_as_duplicate(
                &mut duplicate_report,
                original_id,
                &mut dup_registry,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
        };

        // Verify it's marked as duplicate
        assert!(report_types::is_duplicate(&duplicate_report), 0);
        let dup_of = report_api::get_original_if_duplicate(&duplicate_report);
        assert!(option::is_some(&dup_of), 1);
        assert!(option::destroy_some(dup_of) == original_id, 2);

        ts::return_to_sender(&scenario, duplicate_report);
        ts::end(scenario);
    }

    // ========== Test: Update Report Status ==========

    #[test]
    fun test_update_report_status() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        // Submit report
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                2, // Medium
                1, // Overflow
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"math::overflow"],
                b"overflow_hash",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::next_tx(&mut scenario, RESEARCHER);
        let mut report = ts::take_from_sender<BugReport>(&scenario);

        // Update to UNDER_REVIEW
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            report_api::update_report_status(
                &mut report,
                1, // STATUS_UNDER_REVIEW
                ts::ctx(&mut scenario)
            );
        };

        assert!(report_types::is_under_review(&report), 0);

        // Update to ACCEPTED
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            report_api::update_report_status(
                &mut report,
                2, // STATUS_ACCEPTED
                ts::ctx(&mut scenario)
            );
        };

        assert!(report_types::is_accepted(&report), 1);

        ts::return_to_sender(&scenario, report);
        ts::end(scenario);
    }

    // ========== Test: Invalid Severity ==========

    #[test]
    #[expected_failure(abort_code = 2010)] // E_INVALID_SEVERITY
    fun test_invalid_severity() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        ts::next_tx(&mut scenario, PROJECT_OWNER);
        let program = ts::take_from_sender<BountyProgram>(&scenario);

        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                99, // Invalid severity
                0,
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"test"],
                b"test_hash",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
        };

        ts::return_to_sender(&scenario, program);
        ts::end(scenario);
    }

    // ========== Test: Invalid Category ==========

    #[test]
    #[expected_failure(abort_code = 2011)] // E_INVALID_CATEGORY
    fun test_invalid_category() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        ts::next_tx(&mut scenario, PROJECT_OWNER);
        let program = ts::take_from_sender<BountyProgram>(&scenario);

        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                0,
                99, // Invalid category
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"test"],
                b"test_hash",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
        };

        ts::return_to_sender(&scenario, program);
        ts::end(scenario);
    }

    // ========== Test: Fee Too Low ==========

    #[test]
    #[expected_failure(abort_code = 2012)] // E_FEE_TOO_LOW
    fun test_fee_too_low() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        ts::next_tx(&mut scenario, PROJECT_OWNER);
        let program = ts::take_from_sender<BountyProgram>(&scenario);

        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(ONE_SUI, &mut scenario); // Only 1 SUI, need 10

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                0,
                0,
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"test"],
                b"test_hash",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
        };

        ts::return_to_sender(&scenario, program);
        ts::end(scenario);
    }

    // ========== Test: Registry Statistics ==========

    #[test]
    fun test_registry_statistics() {
        let mut scenario = setup_test();
        create_test_program(&mut scenario);

        // Submit first report
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, &mut scenario);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                0, 0,
                TEST_BLOB_ID,
                vector[], // Empty vector for None
                vector[b"target1"],
                b"hash1",
                submission_fee,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(dup_registry);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::next_tx(&mut scenario, RESEARCHER);
        let report1 = ts::take_from_sender<BugReport>(&scenario);

        // Register first report
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut dup_registry = ts::take_shared<DuplicateRegistry>(&scenario);
            report_api::register_accepted_report(&mut dup_registry, &report1);

            let (registered, duplicates) = report_api::get_registry_stats(&dup_registry);
            assert!(registered == 1, 0);
            assert!(duplicates == 0, 1);

            ts::return_shared(dup_registry);
        };

        ts::return_to_sender(&scenario, report1);
        ts::end(scenario);
    }
}
