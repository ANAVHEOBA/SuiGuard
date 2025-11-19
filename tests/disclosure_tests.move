#[test_only]
module suiguard::disclosure_tests {
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
    const MIN_SUBMISSION_FEE: u64 = 10_000_000_000; // 10 SUI

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

    // Helper to create a bug report
    fun create_report(scenario: &mut Scenario) {
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
                3,
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
    }

    #[test]
    fun test_disclosure_deadline_calculation() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Check disclosure deadline is 90 days from submission
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            let submitted_at = report_types::submitted_at(&report);
            let deadline = report_types::disclosure_deadline(&report);

            // Deadline should be 90 epochs after submission
            assert!(deadline == submitted_at + 90, 0);
            assert!(!report_types::publicly_disclosed(&report), 1);

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_check_disclosure_status_before_deadline() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Check status before deadline
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            let current_epoch = report_types::submitted_at(&report) + 50; // 50 days after submission
            let (can_disclose, reason, time_remaining) = disclosure_api::check_disclosure_status(&report, current_epoch);

            assert!(!can_disclose, 0);
            assert!(reason == 2, 1); // Reason 2 = deadline not reached
            assert!(time_remaining == 40, 2); // 90 - 50 = 40 days remaining

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_check_disclosure_status_after_deadline() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Check status after deadline
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            let current_epoch = report_types::submitted_at(&report) + 95; // 95 days after submission
            let (can_disclose, reason, time_remaining) = disclosure_api::check_disclosure_status(&report, current_epoch);

            assert!(can_disclose, 0);
            assert!(reason == 0, 1); // Reason 0 = deadline reached
            assert!(time_remaining == 0, 2);

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_trigger_public_disclosure_after_90_days() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Fast forward 90+ days
        let mut i = 0;
        while (i < 91) {
            ts::next_epoch(&mut scenario, ADMIN);
            i = i + 1;
        };

        ts::next_tx(&mut scenario, PUBLIC);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            disclosure_api::trigger_public_disclosure(
                &mut report,
                b"public_seal_policy",
                ts::ctx(&mut scenario)
            );

            // Verify disclosure
            assert!(report_types::publicly_disclosed(&report), 0);
            let disclosed_at = report_types::disclosed_at(&report);
            assert!(std::option::is_some(&disclosed_at), 1);

            let public_policy = report_types::public_seal_policy(&report);
            assert!(std::option::is_some(&public_policy), 2);

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 9003)] // E_DEADLINE_NOT_REACHED
    fun test_cannot_disclose_before_deadline() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Try to disclose before 90 days - should fail
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            // Try to trigger disclosure (epoch is still at submission time)
            disclosure_api::trigger_public_disclosure(
                &mut report,
                b"public_seal_policy",
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_request_early_disclosure() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Project submits fix
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            report_response::submit_fix(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                @0xF1ED,
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Request early disclosure
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            disclosure_api::request_early_disclosure(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                ts::ctx(&mut scenario)
            );

            // Verify request was recorded
            assert!(report_types::early_disclosure_requested(&report), 0);
            assert!(!report_types::early_disclosure_approved(&report), 1);

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 9004)] // E_FIX_NOT_SUBMITTED
    fun test_cannot_request_early_disclosure_without_fix() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Try to request early disclosure without submitting fix - should fail
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            disclosure_api::request_early_disclosure(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_approve_early_disclosure() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Submit fix
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            report_response::submit_fix(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                @0xF1ED,
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Request early disclosure
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            disclosure_api::request_early_disclosure(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Researcher approves early disclosure
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            disclosure_api::approve_early_disclosure(
                &mut report,
                b"public_seal_policy_early",
                ts::ctx(&mut scenario)
            );

            // Verify approval and disclosure
            assert!(report_types::early_disclosure_approved(&report), 0);
            assert!(report_types::publicly_disclosed(&report), 1);

            let public_policy = report_types::public_seal_policy(&report);
            assert!(std::option::is_some(&public_policy), 2);

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_reject_early_disclosure() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Submit fix
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            report_response::submit_fix(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                @0xF1ED,
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Request early disclosure
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            disclosure_api::request_early_disclosure(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Researcher rejects early disclosure
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            disclosure_api::reject_early_disclosure(
                &mut report,
                ts::ctx(&mut scenario)
            );

            // Verify still requested but not approved
            assert!(report_types::early_disclosure_requested(&report), 0);
            assert!(!report_types::early_disclosure_approved(&report), 1);
            assert!(!report_types::publicly_disclosed(&report), 2);

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_get_disclosure_details() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            let (deadline, is_disclosed, disclosed_at, early_requested, early_approved) =
                disclosure_api::get_disclosure_details(&report);

            let submitted_at = report_types::submitted_at(&report);
            assert!(deadline == submitted_at + 90, 0);
            assert!(!is_disclosed, 1);
            assert!(disclosed_at == 0, 2);
            assert!(!early_requested, 3);
            assert!(!early_approved, 4);

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_time_until_disclosure() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            let submitted_at = report_types::submitted_at(&report);
            let current_epoch = submitted_at + 30;

            let time_remaining = disclosure_api::time_until_disclosure(&report, current_epoch);
            assert!(time_remaining == 60, 0); // 90 - 30 = 60

            // Test at deadline
            let time_at_deadline = disclosure_api::time_until_disclosure(&report, submitted_at + 90);
            assert!(time_at_deadline == 0, 1);

            // Test after deadline
            let time_after = disclosure_api::time_until_disclosure(&report, submitted_at + 100);
            assert!(time_after == 0, 2);

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 9002)] // E_ALREADY_DISCLOSED
    fun test_cannot_disclose_twice() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Advance 90+ epochs to pass disclosure deadline
        let mut i = 0;
        while (i < 91) {
            ts::next_epoch(&mut scenario, ADMIN);
            i = i + 1;
        };

        // First disclosure (after 90 days)
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            disclosure_api::trigger_public_disclosure(
                &mut report,
                b"public_seal_policy",
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
        };

        // Try to disclose again - should fail with E_ALREADY_DISCLOSED
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            disclosure_api::trigger_public_disclosure(
                &mut report,
                b"public_seal_policy_2",
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 9000)] // E_NOT_RESEARCHER
    fun test_only_researcher_can_approve_early_disclosure() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_report(&mut scenario);

        // Submit fix and request early disclosure
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            report_response::submit_fix(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                @0xF1ED,
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            disclosure_api::request_early_disclosure(
                &mut report,
                &program,
                b"fix_commit_hash_123",
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Try to approve as non-researcher - should fail
        ts::next_tx(&mut scenario, PUBLIC);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            disclosure_api::approve_early_disclosure(
                &mut report,
                b"public_seal_policy_early",
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }
}
