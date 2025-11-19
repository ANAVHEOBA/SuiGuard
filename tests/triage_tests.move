#[test_only]
module suiguard::triage_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::object::{Self, ID};

    use suiguard::bounty_api;
    use suiguard::bounty_types::BountyProgram;
    use suiguard::bounty_registry::ProgramRegistry;
    use suiguard::bounty_init;
    use suiguard::report_api;
    use suiguard::report_types::{Self, BugReport};
    use suiguard::duplicate_registry::DuplicateRegistry;
    use suiguard::report_init;
    use suiguard::triage_types::{Self, TriageVote, TriageRegistry};
    use suiguard::triage_api as triage;
    use suiguard::triage_init;

    // Test addresses
    const ADMIN: address = @0xAD;
    const PROJECT_OWNER: address = @0xA1;
    const RESEARCHER: address = @0xBEEF;
    const VOTER1: address = @0xA111;
    const VOTER2: address = @0xA222;
    const VOTER3: address = @0xA333;

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
    const SEVERITY_LOW: u8 = 3;
    const SEVERITY_INVALID: u8 = 4;

    // Helper to mint test SUI coins
    fun mint_sui(amount: u64, ctx: &mut sui::tx_context::TxContext): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ctx)
    }

    // Helper function to setup bounty program
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

    // Helper function to create a bug report and return its ID and program ID
    fun setup_bug_report(scenario: &mut Scenario): (ID, ID) {
        ts::next_tx(scenario, RESEARCHER);
        {
            report_init::init_for_testing(ts::ctx(scenario));
        };

        ts::next_tx(scenario, RESEARCHER);
        {
            let program = ts::take_from_address<BountyProgram>(scenario, PROJECT_OWNER);
            let dup_registry = ts::take_shared<DuplicateRegistry>(scenario);
            let submission_fee = mint_sui(MIN_SUBMISSION_FEE, ts::ctx(scenario));

            let program_id = object::id(&program);

            report_api::submit_bug_report(
                &program,
                &dup_registry,
                SEVERITY_CRITICAL,
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

            program_id
        };

        // Get the report ID
        ts::next_tx(scenario, RESEARCHER);
        let report = ts::take_from_sender<BugReport>(scenario);
        let report_id = object::id(&report);
        let program_id = report_types::program_id(&report);
        ts::return_to_sender(scenario, report);

        (report_id, program_id)
    }

    #[test]
    fun test_create_triage_vote() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        // Initialize triage system
        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        // Create triage vote
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000, // 10,000 SUI quorum
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Verify vote was created and is shared
        ts::next_tx(&mut scenario, VOTER1);
        {
            let vote = ts::take_shared<TriageVote>(&scenario);

            let (status, _final_severity, total_staked, _deadline) = triage::get_vote_status(&vote);
            assert!(status == triage_types::status_active(), 0);
            assert!(total_staked == 0, 1);

            ts::return_shared(vote);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_cast_vote_single_voter() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000,
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Cast vote
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(5_000_000_000_000, ts::ctx(&mut scenario)); // 5,000 SUI

            triage::cast_vote(
                &mut vote,
                SEVERITY_CRITICAL,
                stake,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(vote);
        };

        // Verify vote was recorded
        ts::next_tx(&mut scenario, VOTER1);
        {
            let vote = ts::take_shared<TriageVote>(&scenario);

            let (severity, stake, claimed) = triage::get_voter_info(&vote, VOTER1);
            assert!(severity == SEVERITY_CRITICAL, 0);
            assert!(stake == 5_000_000_000_000, 1);
            assert!(claimed == false, 2);

            let (_status, _final_severity, total_staked, _deadline) = triage::get_vote_status(&vote);
            assert!(total_staked == 5_000_000_000_000, 3);

            ts::return_shared(vote);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_multiple_voters_different_severities() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        // Create vote
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000,
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // VOTER1: 6000 SUI for CRITICAL
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(6_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_CRITICAL, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // VOTER2: 3000 SUI for HIGH
        ts::next_tx(&mut scenario, VOTER2);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(3_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_HIGH, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // VOTER3: 2000 SUI for CRITICAL (joins majority)
        ts::next_tx(&mut scenario, VOTER3);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(2_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_CRITICAL, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // Verify total stake and distribution
        ts::next_tx(&mut scenario, VOTER1);
        {
            let vote = ts::take_shared<TriageVote>(&scenario);

            let (_status, _final_severity, total_staked, _deadline) = triage::get_vote_status(&vote);
            assert!(total_staked == 11_000_000_000_000, 0); // 6000 + 3000 + 2000

            let distribution = triage::get_vote_distribution(&vote);
            assert!(*std::vector::borrow(&distribution, (SEVERITY_CRITICAL as u64)) == 8_000_000_000_000, 1); // 6000 + 2000
            assert!(*std::vector::borrow(&distribution, (SEVERITY_HIGH as u64)) == 3_000_000_000_000, 2);

            ts::return_shared(vote);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_finalize_triage_with_quorum() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        // Create vote
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000, // 10,000 SUI quorum
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Cast votes to meet quorum
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(7_000_000_000_000, ts::ctx(&mut scenario)); // 7,000 SUI for CRITICAL

            triage::cast_vote(&mut vote, SEVERITY_CRITICAL, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        ts::next_tx(&mut scenario, VOTER2);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(4_000_000_000_000, ts::ctx(&mut scenario)); // 4,000 SUI for HIGH

            triage::cast_vote(&mut vote, SEVERITY_HIGH, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // Advance time past voting deadline (100 + 1 epochs)
        let mut i = 0;
        while (i < 101) {  // Reduced from 57,601 for testing (need 101 to pass deadline of 100)
            ts::next_epoch(&mut scenario, ADMIN);
            i = i + 1;
        };

        // Finalize the vote
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);

            triage::finalize_triage(&mut vote, ts::ctx(&mut scenario));

            let (status, final_severity, _total_staked, _deadline) = triage::get_vote_status(&vote);
            assert!(status == triage_types::status_finalized(), 0);
            assert!(final_severity == SEVERITY_CRITICAL, 1); // CRITICAL won (7000 vs 4000)

            ts::return_shared(vote);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_claim_voting_rewards_majority_voter() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        // Create vote
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000,
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // VOTER1: 6000 SUI for CRITICAL (majority)
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(6_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_CRITICAL, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // VOTER2: 4000 SUI for HIGH (minority - will be slashed)
        ts::next_tx(&mut scenario, VOTER2);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(4_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_HIGH, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // Advance time and finalize (57,600 + 1 epochs)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut i = 0;
            while (i < 101) {  // Reduced from 57,601 for testing (need 101 to pass deadline of 100)
                ts::next_epoch(&mut scenario, ADMIN);
                i = i + 1;
            };
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);

            triage::finalize_triage(&mut vote, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // VOTER1 claims reward (should get 100% of slashed amount since they're the only majority voter)
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);

            triage::claim_voting_rewards(&mut vote, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // Verify VOTER1 received reward
        ts::next_tx(&mut scenario, VOTER1);
        {
            let reward_coin = ts::take_from_sender<Coin<SUI>>(&scenario);
            let reward_value = coin::value(&reward_coin);

            // Total payout = original stake (6000) + reward share (400 SUI = 10% of 4000)
            assert!(reward_value == 6_400_000_000_000, 0);

            ts::return_to_sender(&scenario, reward_coin);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_proportional_reward_distribution() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000,
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // VOTER1: 6000 SUI for CRITICAL (60% of majority stake)
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(6_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_CRITICAL, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // VOTER3: 4000 SUI for CRITICAL (40% of majority stake)
        ts::next_tx(&mut scenario, VOTER3);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(4_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_CRITICAL, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // VOTER2: 5000 SUI for HIGH (minority - will be slashed 500 SUI)
        ts::next_tx(&mut scenario, VOTER2);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(5_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_HIGH, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // Finalize (57,600 + 1 epochs)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut i = 0;
            while (i < 101) {  // Reduced from 57,601 for testing (need 101 to pass deadline of 100)
                ts::next_epoch(&mut scenario, ADMIN);
                i = i + 1;
            };
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            triage::finalize_triage(&mut vote, ts::ctx(&mut scenario));
            ts::return_shared(vote);
        };

        // VOTER1 claims (stake 6000 + 60% of 500 SUI reward = 6300 SUI total)
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            triage::claim_voting_rewards(&mut vote, ts::ctx(&mut scenario));
            ts::return_shared(vote);
        };

        ts::next_tx(&mut scenario, VOTER1);
        {
            let reward = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&reward) == 6_300_000_000_000, 0); // 6000 stake + 300 reward
            ts::return_to_sender(&scenario, reward);
        };

        // VOTER3 claims (stake 4000 + 40% of 500 SUI reward = 4200 SUI total)
        ts::next_tx(&mut scenario, VOTER3);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            triage::claim_voting_rewards(&mut vote, ts::ctx(&mut scenario));
            ts::return_shared(vote);
        };

        ts::next_tx(&mut scenario, VOTER3);
        {
            let reward = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&reward) == 4_200_000_000_000, 0); // 4000 stake + 200 reward
            ts::return_to_sender(&scenario, reward);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 100)] // E_VOTING_ENDED from triage_voting
    fun test_cannot_vote_after_deadline() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000,
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Advance past deadline (57,600 + 1 epochs)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut i = 0;
            while (i < 101) {  // Reduced from 57,601 for testing (need 101 to pass deadline of 100)
                ts::next_epoch(&mut scenario, ADMIN);
                i = i + 1;
            };
        };

        // This should fail
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(5_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_CRITICAL, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 103)] // E_ALREADY_VOTED from triage_voting
    fun test_cannot_vote_twice() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000,
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // First vote
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(5_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_CRITICAL, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        // Second vote - should fail
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(3_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, SEVERITY_HIGH, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 104)] // E_INVALID_SEVERITY from triage_voting
    fun test_invalid_severity_choice() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        let (report_id, program_id) = setup_bug_report(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            triage_init::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut registry = ts::take_shared<TriageRegistry>(&scenario);

            // Use custom deadline (100 epochs instead of default 57,600)
            triage::create_triage_vote_with_deadline(
                &mut registry,
                report_id,
                program_id,
                10_000_000_000_000,
                100,  // voting period in epochs
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Vote with invalid severity (5 is out of range)
        ts::next_tx(&mut scenario, VOTER1);
        {
            let mut vote = ts::take_shared<TriageVote>(&scenario);
            let stake = mint_sui(5_000_000_000_000, ts::ctx(&mut scenario));

            triage::cast_vote(&mut vote, 5, stake, ts::ctx(&mut scenario));

            ts::return_shared(vote);
        };

        ts::end(scenario);
    }
}
