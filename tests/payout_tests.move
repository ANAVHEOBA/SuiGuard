#[test_only]
module suiguard::payout_tests {
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
    use suiguard::payout_api;
    use suiguard::split_api;
    use suiguard::payout_types::SplitProposal;

    // Test addresses
    const ADMIN: address = @0xAD;
    const PROJECT_OWNER: address = @0xA1;
    const RESEARCHER: address = @0xBEEF;
    const RESEARCHER2: address = @0xBEE2;
    const RESEARCHER3: address = @0xBEE3;

    // Test amounts
    const ONE_SUI: u64 = 1_000_000_000;

    // Valid Walrus blob IDs for testing (32+ bytes)
    const TEST_BLOB_ID: vector<u8> = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const THOUSAND_SUI: u64 = 1_000_000_000_000;
    const MIN_SUBMISSION_FEE: u64 = 10_000_000_000; // 10 SUI

    // Severity levels
    const SEVERITY_CRITICAL: u8 = 0;
    const SEVERITY_HIGH: u8 = 1;
    const SEVERITY_MEDIUM: u8 = 2;

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
                50_000 * ONE_SUI,  // Critical: 50k SUI
                20_000 * ONE_SUI,  // High: 20k SUI
                5_000 * ONE_SUI,   // Medium: 5k SUI
                1_000 * ONE_SUI,   // Low: 1k SUI
                100 * ONE_SUI,     // Info: 100 SUI
                TEST_BLOB_ID,
                90,
                ts::ctx(scenario)
            );

            ts::return_shared(registry);
        };
    }

    // Helper to create and accept a bug report
    fun create_and_accept_report(scenario: &mut Scenario, severity: u8) {
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
                severity,
                3, // category
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

        // Accept the report
        ts::next_tx(scenario, PROJECT_OWNER);
        {
            let mut report = ts::take_from_address<BugReport>(scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(scenario, PROJECT_OWNER);

            report_types::set_status(&mut report, report_types::status_accepted());

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };
    }

    #[test]
    fun test_execute_payout_critical() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        // Execute payout
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let mut program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            payout_api::execute_payout(&mut report, &mut program, ts::ctx(&mut scenario));

            // Verify payout executed
            assert!(report_types::payout_executed(&report), 0);
            assert!(report_types::payout_amount(&report) == 50_000 * ONE_SUI, 1);
            assert!(report_types::is_paid(&report), 2);

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Verify researcher received payment
        // Note: take_from_sender returns most recent transfer first
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            // Fee refund was transferred last, so take it first
            let fee_coin = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&fee_coin) == MIN_SUBMISSION_FEE, 3);
            ts::return_to_sender(&scenario, fee_coin);

            // Payout was transferred first, so take it second
            let payout_coin = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&payout_coin) == 50_000 * ONE_SUI, 4);
            ts::return_to_sender(&scenario, payout_coin);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_execute_payout_high() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_HIGH);

        // Execute payout
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let mut program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            payout_api::execute_payout(&mut report, &mut program, ts::ctx(&mut scenario));

            assert!(report_types::payout_amount(&report) == 20_000 * ONE_SUI, 0);

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6002)] // E_REPORT_NOT_ACCEPTED (status changes to PAID after first payout)
    fun test_cannot_execute_payout_twice() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        // First payout
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let mut program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            payout_api::execute_payout(&mut report, &mut program, ts::ctx(&mut scenario));

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Second payout - should fail
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let mut program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            payout_api::execute_payout(&mut report, &mut program, ts::ctx(&mut scenario));

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_propose_split_payment() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        // Propose split
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            // 60% to RESEARCHER, 30% to RESEARCHER2, 10% to RESEARCHER3
            let recipients = vector[RESEARCHER, RESEARCHER2, RESEARCHER3];
            let percentages = vector[6000u64, 3000u64, 1000u64];

            split_api::propose_split(
                &mut report,
                &program,
                recipients,
                percentages,
                ts::ctx(&mut scenario)
            );

            assert!(report_types::has_split_proposal(&report), 0);

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Verify proposal created
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let proposal = ts::take_from_sender<SplitProposal>(&scenario);
            let (total, num_recipients, all_approved, executed) = split_api::get_proposal_status(&proposal);

            assert!(total == 50_000 * ONE_SUI, 1);
            assert!(num_recipients == 3, 2);
            assert!(!all_approved, 3);
            assert!(!executed, 4);

            ts::return_to_sender(&scenario, proposal);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_approve_and_execute_split() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        // Propose split
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            let recipients = vector[RESEARCHER, RESEARCHER2, RESEARCHER3];
            let percentages = vector[6000u64, 3000u64, 1000u64];

            split_api::propose_split(
                &mut report,
                &program,
                recipients,
                percentages,
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // RESEARCHER approves
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut proposal = ts::take_from_sender<SplitProposal>(&scenario);
            split_api::approve_split(&mut proposal, ts::ctx(&mut scenario));
            assert!(split_api::has_approved(&proposal, RESEARCHER), 0);
            ts::return_to_sender(&scenario, proposal);
        };

        // RESEARCHER2 approves
        ts::next_tx(&mut scenario, RESEARCHER2);
        {
            let mut proposal = ts::take_from_address<SplitProposal>(&scenario, RESEARCHER);
            split_api::approve_split(&mut proposal, ts::ctx(&mut scenario));
            assert!(split_api::has_approved(&proposal, RESEARCHER2), 1);
            ts::return_to_address(RESEARCHER, proposal);
        };

        // RESEARCHER3 approves
        ts::next_tx(&mut scenario, RESEARCHER3);
        {
            let mut proposal = ts::take_from_address<SplitProposal>(&scenario, RESEARCHER);
            split_api::approve_split(&mut proposal, ts::ctx(&mut scenario));
            assert!(split_api::has_approved(&proposal, RESEARCHER3), 2);

            let (_, _, all_approved, _) = split_api::get_proposal_status(&proposal);
            assert!(all_approved, 3);

            ts::return_to_address(RESEARCHER, proposal);
        };

        // Execute split payout
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut proposal = ts::take_from_sender<SplitProposal>(&scenario);
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let mut program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            split_api::execute_split_payout(
                &mut proposal,
                &mut report,
                &mut program,
                ts::ctx(&mut scenario)
            );

            assert!(report_types::payout_executed(&report), 4);
            assert!(!report_types::has_split_proposal(&report), 5);

            ts::return_to_sender(&scenario, proposal);
            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Verify RESEARCHER received 60% split + fee refund
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            // Fee refund was transferred last, so take it first
            let fee_coin = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&fee_coin) == MIN_SUBMISSION_FEE, 6);
            ts::return_to_sender(&scenario, fee_coin);

            // Split payout (60% of 50k = 30k)
            let payout = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&payout) == 30_000 * ONE_SUI, 7); // 60% of 50k
            ts::return_to_sender(&scenario, payout);
        };

        // Verify RESEARCHER2 received 30%
        ts::next_tx(&mut scenario, RESEARCHER2);
        {
            let payout = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&payout) == 15_000 * ONE_SUI, 8); // 30% of 50k
            ts::return_to_sender(&scenario, payout);
        };

        // Verify RESEARCHER3 received 10%
        ts::next_tx(&mut scenario, RESEARCHER3);
        {
            let payout = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&payout) == 5_000 * ONE_SUI, 9); // 10% of 50k
            ts::return_to_sender(&scenario, payout);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_check_payout_eligibility() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            let (eligible, reason, amount) = payout_api::check_payout_eligibility(&report, &program);
            assert!(eligible, 0);
            assert!(reason == 0, 1); // 0 = eligible
            assert!(amount == 50_000 * ONE_SUI, 2);

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 5000)] // E_INVALID_TOTAL_PERCENTAGE
    fun test_split_invalid_percentage_total() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        // Try to propose split with incorrect total (50% + 30% = 80%, not 100%)
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            let recipients = vector[RESEARCHER, RESEARCHER2];
            let percentages = vector[5000u64, 3000u64]; // Only 80%

            split_api::propose_split(
                &mut report,
                &program,
                recipients,
                percentages,
                ts::ctx(&mut scenario)
            );

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        ts::end(scenario);
    }
}
