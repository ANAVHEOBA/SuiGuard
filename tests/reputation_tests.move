#[test_only]
module suiguard::reputation_tests {
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
    use suiguard::reputation_api;
    use suiguard::reputation_types::{Self, ResearcherProfile, AchievementBadge};

    // Test addresses
    const ADMIN: address = @0xAD;
    const PROJECT_OWNER: address = @0xA1;
    const RESEARCHER: address = @0xBEEF;

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
    fun test_create_researcher_profile() {
        let mut scenario = ts::begin(RESEARCHER);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Verify profile created
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            assert!(reputation_types::researcher(&profile) == RESEARCHER, 0);
            assert!(reputation_types::reputation_score(&profile) == 0, 1);
            assert!(reputation_types::tier(&profile) == reputation_types::tier_newbie(), 2);
            assert!(reputation_types::total_bugs(&profile) == 0, 3);
            assert!(reputation_types::total_earnings(&profile) == 0, 4);

            ts::return_to_sender(&scenario, profile);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_update_reputation_critical() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Update reputation after finding critical bug
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            reputation_api::update_reputation(&mut profile, &report, ts::ctx(&mut scenario));

            // Verify reputation updated
            assert!(reputation_types::critical_bugs(&profile) == 1, 0);
            assert!(reputation_types::reputation_score(&profile) == 1000, 1); // 1 critical = 1000 points
            assert!(reputation_types::tier(&profile) == reputation_types::tier_bronze(), 2); // >= 1000 = Bronze

            ts::return_to_sender(&scenario, profile);
            ts::return_to_address(RESEARCHER, report);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_reputation_tier_progression() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Find 5 critical bugs to test tier progression
        let mut i = 0;
        while (i < 5) {
            create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

            ts::next_tx(&mut scenario, RESEARCHER);
            {
                let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
                let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

                reputation_api::update_reputation(&mut profile, &report, ts::ctx(&mut scenario));

                ts::return_to_sender(&scenario, profile);
                ts::return_to_address(RESEARCHER, report);
            };

            i = i + 1;
        };

        // Verify final reputation
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            assert!(reputation_types::critical_bugs(&profile) == 5, 0);
            assert!(reputation_types::reputation_score(&profile) == 5000, 1); // 5 * 1000
            assert!(reputation_types::tier(&profile) == reputation_types::tier_silver(), 2); // >= 5000 = Silver

            ts::return_to_sender(&scenario, profile);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_reputation_bonus_calculation() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Find 100 critical bugs to reach Legend tier
        let mut i = 0;
        while (i < 100) {
            create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

            ts::next_tx(&mut scenario, RESEARCHER);
            {
                let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
                let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

                reputation_api::update_reputation(&mut profile, &report, ts::ctx(&mut scenario));

                ts::return_to_sender(&scenario, profile);
                ts::return_to_address(RESEARCHER, report);
            };

            i = i + 1;
        };

        // Verify Legend tier with 1.15x bonus
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            assert!(reputation_types::critical_bugs(&profile) == 100, 0);
            assert!(reputation_types::reputation_score(&profile) == 100_000, 1); // 100 * 1000
            assert!(reputation_types::tier(&profile) == reputation_types::tier_legend(), 2); // >= 100000 = Legend

            // Test bonus calculation
            let base_amount = 10_000 * ONE_SUI;
            let bonus_amount = reputation_api::calculate_reputation_bonus(&profile, base_amount);
            assert!(bonus_amount == 11_500 * ONE_SUI, 3); // 1.15x bonus for Legend

            ts::return_to_sender(&scenario, profile);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_add_earnings() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Execute payout and add earnings
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            let mut program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            payout_api::execute_payout(&mut report, &mut program, ts::ctx(&mut scenario));

            ts::return_to_address(RESEARCHER, report);
            ts::return_to_address(PROJECT_OWNER, program);
        };

        // Add earnings to profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            let payout_amount = 50_000 * ONE_SUI;

            reputation_api::add_earnings(&mut profile, payout_amount, ts::ctx(&mut scenario));

            assert!(reputation_types::total_earnings(&profile) == payout_amount, 0);

            ts::return_to_sender(&scenario, profile);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_mint_first_blood_achievement() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Update reputation (first bug)
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

            reputation_api::update_reputation(&mut profile, &report, ts::ctx(&mut scenario));

            ts::return_to_sender(&scenario, profile);
            ts::return_to_address(RESEARCHER, report);
        };

        // Mint First Blood achievement
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            assert!(
                reputation_api::check_achievement_eligibility(&profile, reputation_types::achievement_first_blood()),
                0
            );

            reputation_api::mint_achievement(
                &mut profile,
                reputation_types::achievement_first_blood(),
                ts::ctx(&mut scenario)
            );

            ts::return_to_sender(&scenario, profile);
        };

        // Verify badge received
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let badge = ts::take_from_sender<AchievementBadge>(&scenario);

            assert!(reputation_types::badge_owner(&badge) == RESEARCHER, 1);
            assert!(reputation_types::badge_type(&badge) == reputation_types::achievement_first_blood(), 2);
            assert!(reputation_types::badge_name(&badge) == &b"First Blood", 3);

            ts::return_to_sender(&scenario, badge);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_mint_critical_hunter_achievement() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Find 5 critical bugs
        let mut i = 0;
        while (i < 5) {
            create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);

            ts::next_tx(&mut scenario, RESEARCHER);
            {
                let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
                let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);

                reputation_api::update_reputation(&mut profile, &report, ts::ctx(&mut scenario));

                ts::return_to_sender(&scenario, profile);
                ts::return_to_address(RESEARCHER, report);
            };

            i = i + 1;
        };

        // Mint Critical Hunter achievement
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            assert!(
                reputation_api::check_achievement_eligibility(&profile, reputation_types::achievement_critical_hunter()),
                0
            );

            reputation_api::mint_achievement(
                &mut profile,
                reputation_types::achievement_critical_hunter(),
                ts::ctx(&mut scenario)
            );

            ts::return_to_sender(&scenario, profile);
        };

        // Verify badge
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let badge = ts::take_from_sender<AchievementBadge>(&scenario);

            assert!(reputation_types::badge_type(&badge) == reputation_types::achievement_critical_hunter(), 1);
            assert!(reputation_types::badge_name(&badge) == &b"Critical Hunter", 2);

            ts::return_to_sender(&scenario, badge);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 8002)] // E_NOT_ELIGIBLE
    fun test_cannot_mint_achievement_without_eligibility() {
        let mut scenario = ts::begin(RESEARCHER);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Try to mint Critical Hunter without finding 5 critical bugs
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            assert!(
                !reputation_api::check_achievement_eligibility(&profile, reputation_types::achievement_critical_hunter()),
                0
            );

            // This should fail
            reputation_api::mint_achievement(
                &mut profile,
                reputation_types::achievement_critical_hunter(),
                ts::ctx(&mut scenario)
            );

            ts::return_to_sender(&scenario, profile);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_get_researcher_stats() {
        let mut scenario = ts::begin(ADMIN);

        setup_bounty_program(&mut scenario);

        // Create profile
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            reputation_api::create_profile(ts::ctx(&mut scenario));
        };

        // Find different severity bugs
        create_and_accept_report(&mut scenario, SEVERITY_CRITICAL);
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            reputation_api::update_reputation(&mut profile, &report, ts::ctx(&mut scenario));
            ts::return_to_sender(&scenario, profile);
            ts::return_to_address(RESEARCHER, report);
        };

        create_and_accept_report(&mut scenario, SEVERITY_HIGH);
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            reputation_api::update_reputation(&mut profile, &report, ts::ctx(&mut scenario));
            ts::return_to_sender(&scenario, profile);
            ts::return_to_address(RESEARCHER, report);
        };

        create_and_accept_report(&mut scenario, SEVERITY_MEDIUM);
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            let report = ts::take_from_address<BugReport>(&scenario, RESEARCHER);
            reputation_api::update_reputation(&mut profile, &report, ts::ctx(&mut scenario));
            ts::return_to_sender(&scenario, profile);
            ts::return_to_address(RESEARCHER, report);
        };

        // Verify stats
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            let (critical, high, medium, low, total, earnings, score, tier) = reputation_api::get_researcher_stats(&profile);

            assert!(critical == 1, 0);
            assert!(high == 1, 1);
            assert!(medium == 1, 2);
            assert!(low == 0, 3);
            assert!(total == 3, 4);
            assert!(earnings == 0, 5);
            assert!(score == 1600, 6); // (1*1000) + (1*500) + (1*100)
            assert!(tier == reputation_types::tier_bronze(), 7);

            ts::return_to_sender(&scenario, profile);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_tier_bonus_percentages() {
        let mut scenario = ts::begin(RESEARCHER);

        // Test all tier bonuses
        let base_amount = 10_000 * ONE_SUI;

        // Newbie: 1.0x
        let newbie_bonus = reputation_types::apply_bonus(base_amount, reputation_types::tier_newbie());
        assert!(newbie_bonus == 10_000 * ONE_SUI, 0);

        // Bronze: 1.025x
        let bronze_bonus = reputation_types::apply_bonus(base_amount, reputation_types::tier_bronze());
        assert!(bronze_bonus == 10_250 * ONE_SUI, 1);

        // Silver: 1.05x
        let silver_bonus = reputation_types::apply_bonus(base_amount, reputation_types::tier_silver());
        assert!(silver_bonus == 10_500 * ONE_SUI, 2);

        // Gold: 1.075x
        let gold_bonus = reputation_types::apply_bonus(base_amount, reputation_types::tier_gold());
        assert!(gold_bonus == 10_750 * ONE_SUI, 3);

        // Platinum: 1.1x
        let platinum_bonus = reputation_types::apply_bonus(base_amount, reputation_types::tier_platinum());
        assert!(platinum_bonus == 11_000 * ONE_SUI, 4);

        // Legend: 1.15x
        let legend_bonus = reputation_types::apply_bonus(base_amount, reputation_types::tier_legend());
        assert!(legend_bonus == 11_500 * ONE_SUI, 5);

        ts::end(scenario);
    }
}
