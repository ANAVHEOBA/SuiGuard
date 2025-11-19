#[test_only]
module suiguard::bounty_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::test_utils;
    use suiguard::bounty_api;
    use suiguard::bounty_types::{Self, BountyProgram};
    use suiguard::bounty_registry::{Self, ProgramRegistry};
    use suiguard::bounty_init;
    use suiguard::constants;

    // Test addresses
    const ADMIN: address = @0xAD;
    const PROJECT_OWNER: address = @0xA1;
    const RESEARCHER: address = @0xB1;

    // Test amounts (in MIST - 1 SUI = 1_000_000_000 MIST)
    const ONE_SUI: u64 = 1_000_000_000;
    const THOUSAND_SUI: u64 = 1_000_000_000_000;

    // Valid Walrus blob IDs for testing (32+ bytes)
    const TEST_BLOB_ID: vector<u8> = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    const ORIGINAL_BLOB_ID: vector<u8> = b"original0123456789abcdef012345original0123456789abcdef012345678901";
    const UPDATED_BLOB_ID: vector<u8> = b"updated00123456789abcdef012345updated00123456789abcdef0123456789";

    // Helper function to create test scenario with registry
    fun setup_test(): Scenario {
        let mut scenario = ts::begin(ADMIN);
        // Initialize registry
        bounty_init::init_for_testing(ts::ctx(&mut scenario));
        scenario
    }

    // Helper to mint test SUI coins
    fun mint_sui(amount: u64, scenario: &mut Scenario): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    // ========== Test: Successful Bounty Program Creation ==========

    #[test]
    fun test_create_bounty_program_success() {
        let mut scenario = setup_test();

        // Switch to project owner
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario); // 100,000 SUI

            bounty_api::create_bounty_program(
                &mut registry,                        // registry
                b"Test Bug Bounty",                  // name
                b"Test bounty program description",  // description
                escrow,                               // escrow
                50_000 * ONE_SUI,                     // critical: 50k SUI
                20_000 * ONE_SUI,                     // high: 20k SUI
                5_000 * ONE_SUI,                      // medium: 5k SUI
                1_000 * ONE_SUI,                      // low: 1k SUI
                100 * ONE_SUI,                        // informational: 100 SUI
                TEST_BLOB_ID,                         // walrus_blob_id
                90,                                   // duration: 90 days
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Check that program was created
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let program = ts::take_from_sender<BountyProgram>(&scenario);
            
            // Verify program properties
            assert!(bounty_types::project_owner(&program) == PROJECT_OWNER, 0);
            assert!(*bounty_types::name(&program) == b"Test Bug Bounty", 1);
            assert!(bounty_types::is_active(&program), 2);
            assert!(bounty_types::total_escrow_value(&program) == THOUSAND_SUI * 100, 3);
            
            // Verify severity tiers
            assert!(bounty_types::get_tier_amount(&program, constants::severity_critical()) == 50_000 * ONE_SUI, 4);
            assert!(bounty_types::get_tier_amount(&program, constants::severity_high()) == 20_000 * ONE_SUI, 5);
            assert!(bounty_types::get_tier_amount(&program, constants::severity_medium()) == 5_000 * ONE_SUI, 6);
            assert!(bounty_types::get_tier_amount(&program, constants::severity_low()) == 1_000 * ONE_SUI, 7);
            
            ts::return_to_sender(&scenario, program);
        };
        
        ts::end(scenario);
    }

    // ========== Test: Fund Bounty Program ==========

    #[test]
    fun test_fund_bounty_program() {
        let mut scenario = setup_test();

        // Create program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Fund the program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut program = ts::take_from_sender<BountyProgram>(&scenario);
            let additional_funds = mint_sui(THOUSAND_SUI * 50, &mut scenario); // Add 50k SUI
            
            let initial_balance = bounty_types::total_escrow_value(&program);
            
            bounty_api::fund_bounty_program(
                &mut program,
                additional_funds,
                ts::ctx(&mut scenario)
            );
            
            let new_balance = bounty_types::total_escrow_value(&program);
            assert!(new_balance == initial_balance + (THOUSAND_SUI * 50), 0);
            
            ts::return_to_sender(&scenario, program);
        };
        
        ts::end(scenario);
    }

    // ========== Test: Update Severity Tiers ==========

    #[test]
    fun test_update_severity_tiers() {
        let mut scenario = setup_test();

        // Create program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Update tiers
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut program = ts::take_from_sender<BountyProgram>(&scenario);
            
            bounty_api::update_severity_tiers(
                &mut program,
                100_000 * ONE_SUI,  // New critical: 100k SUI
                40_000 * ONE_SUI,   // New high: 40k SUI
                10_000 * ONE_SUI,   // New medium: 10k SUI
                2_000 * ONE_SUI,    // New low: 2k SUI
                200 * ONE_SUI,      // New informational: 200 SUI
                ts::ctx(&mut scenario)
            );
            
            // Verify updated amounts
            assert!(bounty_types::get_tier_amount(&program, constants::severity_critical()) == 100_000 * ONE_SUI, 0);
            assert!(bounty_types::get_tier_amount(&program, constants::severity_high()) == 40_000 * ONE_SUI, 1);
            assert!(bounty_types::get_tier_amount(&program, constants::severity_medium()) == 10_000 * ONE_SUI, 2);
            
            ts::return_to_sender(&scenario, program);
        };
        
        ts::end(scenario);
    }

    // ========== Test: Pause and Resume Program ==========

    #[test]
    fun test_pause_and_resume_program() {
        let mut scenario = setup_test();

        // Create program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Pause program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let mut program = ts::take_from_sender<BountyProgram>(&scenario);

            assert!(bounty_types::is_active(&program), 0);

            bounty_api::pause_program(&mut registry, &mut program, ts::ctx(&mut scenario));

            assert!(!bounty_types::is_active(&program), 1);

            ts::return_to_sender(&scenario, program);
            ts::return_shared(registry);
        };

        // Resume program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let mut program = ts::take_from_sender<BountyProgram>(&scenario);

            bounty_api::resume_program(&mut registry, &mut program, ts::ctx(&mut scenario));

            assert!(bounty_types::is_active(&program), 2);

            ts::return_to_sender(&scenario, program);
            ts::return_shared(registry);
        };
        
        ts::end(scenario);
    }

    // ========== Test: Update Walrus Blob ID ==========

    #[test]
    fun test_update_program_details() {
        let mut scenario = setup_test();

        // Create program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                ORIGINAL_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Update blob ID
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut program = ts::take_from_sender<BountyProgram>(&scenario);
            
            assert!(*bounty_types::walrus_blob_id(&program) == ORIGINAL_BLOB_ID, 0);
            
            bounty_api::update_program_details(
                &mut program,
                UPDATED_BLOB_ID,
                ts::ctx(&mut scenario)
            );

            assert!(*bounty_types::walrus_blob_id(&program) == UPDATED_BLOB_ID, 1);
            
            ts::return_to_sender(&scenario, program);
        };
        
        ts::end(scenario);
    }

    // ========== Test: Error Cases ==========

    #[test]
    #[expected_failure(abort_code = 1001)] // e_escrow_too_low
    fun test_create_with_insufficient_escrow() {
        let mut scenario = setup_test();

        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(100 * ONE_SUI, &mut scenario); // Only 100 SUI (too low)

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1002)] // e_invalid_tier_order
    fun test_create_with_invalid_tier_order() {
        let mut scenario = setup_test();

        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            // Invalid: High tier is greater than Critical tier
            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                10_000 * ONE_SUI,   // critical (too low!)
                20_000 * ONE_SUI,   // high (higher than critical - invalid!)
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1003)] // e_empty_name
    fun test_create_with_empty_name() {
        let mut scenario = setup_test();

        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"",  // Empty name
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006)] // e_not_program_owner
    fun test_non_owner_cannot_fund() {
        let mut scenario = setup_test();

        // Create program as PROJECT_OWNER
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Try to fund as different user (should fail)
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);
            let additional_funds = mint_sui(THOUSAND_SUI * 10, &mut scenario);
            
            bounty_api::fund_bounty_program(
                &mut program,
                additional_funds,
                ts::ctx(&mut scenario)
            );
            
            ts::return_to_address(PROJECT_OWNER, program);
        };
        
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1006)] // e_not_program_owner
    fun test_non_owner_cannot_pause() {
        let mut scenario = setup_test();

        // Create program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Try to pause as different user (should fail)
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let mut program = ts::take_from_address<BountyProgram>(&scenario, PROJECT_OWNER);

            bounty_api::pause_program(&mut registry, &mut program, ts::ctx(&mut scenario));

            ts::return_to_address(PROJECT_OWNER, program);
            ts::return_shared(registry);
        };
        
        ts::end(scenario);
    }

    // ========== Test: Discovery Features ==========

    #[test]
    fun test_program_discovery() {
        let mut scenario = setup_test();

        // Check initial registry state
        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<ProgramRegistry>(&scenario);

            let (total, active) = bounty_api::get_registry_stats(&registry);
            assert!(total == 0, 0);
            assert!(active == 0, 1);

            ts::return_shared(registry);
        };

        // Create first program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"First Bounty",
                b"Description 1",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Check registry stats after first program
        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<ProgramRegistry>(&scenario);

            let (total, active) = bounty_api::get_registry_stats(&registry);
            assert!(total == 1, 2);
            assert!(active == 1, 3);

            ts::return_shared(registry);
        };

        // Create second program
        ts::next_tx(&mut scenario, RESEARCHER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 50, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"Second Bounty",
                b"Description 2",
                escrow,
                25_000 * ONE_SUI,
                10_000 * ONE_SUI,
                2_500 * ONE_SUI,
                500 * ONE_SUI,
                50 * ONE_SUI,
                TEST_BLOB_ID,
                60,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Check registry stats after second program
        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<ProgramRegistry>(&scenario);

            let (total, active) = bounty_api::get_registry_stats(&registry);
            assert!(total == 2, 4);
            assert!(active == 2, 5);

            ts::return_shared(registry);
        };

        // Test get_program_stats
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let program = ts::take_from_sender<BountyProgram>(&scenario);

            let info = bounty_api::get_program_stats(&program);

            assert!(*bounty_registry::info_name(&info) == b"First Bounty", 6);
            assert!(bounty_registry::info_total_escrow(&info) == THOUSAND_SUI * 100, 7);
            assert!(bounty_registry::info_critical_payout(&info) == 50_000 * ONE_SUI, 8);
            assert!(bounty_registry::info_is_active(&info), 9);
            assert!(bounty_registry::info_total_reports(&info) == 0, 10);
            assert!(bounty_registry::info_total_resolved(&info) == 0, 11);
            assert!(bounty_registry::info_total_payouts(&info) == 0, 12);

            ts::return_to_sender(&scenario, program);
        };

        // Pause first program and check registry stats
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let mut program = ts::take_from_sender<BountyProgram>(&scenario);

            bounty_api::pause_program(&mut registry, &mut program, ts::ctx(&mut scenario));

            let (total, active) = bounty_api::get_registry_stats(&registry);
            assert!(total == 2, 13);
            assert!(active == 1, 14); // One paused, one still active

            ts::return_to_sender(&scenario, program);
            ts::return_shared(registry);
        };

        // Resume and check stats
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let mut program = ts::take_from_sender<BountyProgram>(&scenario);

            bounty_api::resume_program(&mut registry, &mut program, ts::ctx(&mut scenario));

            let (total, active) = bounty_api::get_registry_stats(&registry);
            assert!(total == 2, 15);
            assert!(active == 2, 16); // Both active again

            ts::return_to_sender(&scenario, program);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    // ========== Test: View Functions ==========

    #[test]
    fun test_view_functions() {
        let mut scenario = setup_test();

        // Create program
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let mut registry = ts::take_shared<ProgramRegistry>(&scenario);
            let escrow = mint_sui(THOUSAND_SUI * 100, &mut scenario);

            bounty_api::create_bounty_program(
                &mut registry,
                b"Test Bounty",
                b"Description",
                escrow,
                50_000 * ONE_SUI,
                20_000 * ONE_SUI,
                5_000 * ONE_SUI,
                1_000 * ONE_SUI,
                100 * ONE_SUI,
                TEST_BLOB_ID,
                90,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Test view functions
        ts::next_tx(&mut scenario, PROJECT_OWNER);
        {
            let program = ts::take_from_sender<BountyProgram>(&scenario);

            // Test is_accepting_reports
            assert!(bounty_api::is_accepting_reports(&program, ts::ctx(&mut scenario)), 0);
            
            // Test get_available_funds
            assert!(bounty_api::get_available_funds(&program) == THOUSAND_SUI * 100, 1);
            
            ts::return_to_sender(&scenario, program);
        };
        
        ts::end(scenario);
    }
}
