/// Public API for bounty program operations
/// These are the entry functions that external users call
module suiguard::bounty_api {
    use sui::transfer;
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::object;
    use suiguard::bounty_types;
    use sui::tx_context::{Self, TxContext};
    use suiguard::bounty_types::BountyProgram;
    use suiguard::bounty_crud;
    use suiguard::bounty_registry::{Self, ProgramRegistry, ProgramInfo};
    use suiguard::constants;

    // ========== Public Entry Functions ==========

    /// Create a new bounty program with escrowed funds
    ///
    /// # Arguments
    /// * `registry` - Shared program registry for discovery
    /// * `name` - Name of the bounty program (1-100 bytes)
    /// * `description` - Short description
    /// * `escrow` - Initial escrow funds (minimum 1000 SUI)
    /// * `critical_amount` - Payout for Critical severity bugs
    /// * `high_amount` - Payout for High severity bugs
    /// * `medium_amount` - Payout for Medium severity bugs
    /// * `low_amount` - Payout for Low severity bugs
    /// * `informational_amount` - Payout for Informational reports (can be 0)
    /// * `walrus_blob_id` - Walrus blob ID containing program details
    /// * `duration_days` - How long the program runs (30-365 days)
    ///
    /// # Returns
    /// Creates a BountyProgram object and transfers it to the caller
    public entry fun create_bounty_program(
        registry: &mut ProgramRegistry,
        name: vector<u8>,
        description: vector<u8>,
        escrow: Coin<SUI>,
        critical_amount: u64,
        high_amount: u64,
        medium_amount: u64,
        low_amount: u64,
        informational_amount: u64,
        walrus_blob_id: vector<u8>,
        duration_days: u64,
        ctx: &mut TxContext
    ) {
        use suiguard::walrus;

        // Validate Walrus blob ID format
        walrus::assert_valid_blob_id(&walrus_blob_id);

        let program = bounty_crud::create(
            name,
            description,
            escrow,
            critical_amount,
            high_amount,
            medium_amount,
            low_amount,
            informational_amount,
            walrus_blob_id,
            duration_days,
            ctx
        );

        // Register in discovery registry
        let program_id = object::uid_to_inner(bounty_types::id(&program));
        let owner = tx_context::sender(ctx);
        bounty_registry::register_program(registry, program_id, owner);

        // Transfer ownership to caller (project owner)
        transfer::public_transfer(program, owner);
    }

    /// Add additional funding to an existing bounty program
    /// 
    /// # Arguments
    /// * `program` - Mutable reference to the bounty program
    /// * `additional_funds` - Additional SUI to add to escrow
    public entry fun fund_bounty_program(
        program: &mut BountyProgram,
        additional_funds: Coin<SUI>,
        ctx: &TxContext
    ) {
        // Only program owner can add funds
        assert!(
            bounty_types::project_owner(program) == tx_context::sender(ctx),
            constants::e_not_program_owner()
        );

        bounty_crud::fund(program, additional_funds);
    }

    /// Update severity tier payout amounts
    /// 
    /// # Arguments
    /// * `program` - Mutable reference to the bounty program
    /// * All amount parameters - New payout amounts for each severity
    public entry fun update_severity_tiers(
        program: &mut BountyProgram,
        critical_amount: u64,
        high_amount: u64,
        medium_amount: u64,
        low_amount: u64,
        informational_amount: u64,
        ctx: &TxContext
    ) {
        // Only program owner can update tiers
        assert!(
            bounty_types::project_owner(program) == tx_context::sender(ctx),
            constants::e_not_program_owner()
        );

        // Program must be active
        assert!(
            bounty_types::is_active(program),
            constants::e_program_not_active()
        );

        bounty_crud::update_tiers(
            program,
            critical_amount,
            high_amount,
            medium_amount,
            low_amount,
            informational_amount,
        );
    }

    /// Pause the bounty program (stop accepting new reports)
    ///
    /// # Arguments
    /// * `registry` - Shared program registry
    /// * `program` - Mutable reference to the bounty program
    public entry fun pause_program(
        registry: &mut ProgramRegistry,
        program: &mut BountyProgram,
        ctx: &TxContext
    ) {
        // Only program owner can pause
        assert!(
            bounty_types::project_owner(program) == tx_context::sender(ctx),
            constants::e_not_program_owner()
        );

        bounty_crud::pause(program, ctx);

        // Update registry
        let program_id = object::uid_to_inner(bounty_types::id(program));
        bounty_registry::mark_inactive(registry, program_id);
    }

    /// Resume a paused bounty program
    ///
    /// # Arguments
    /// * `registry` - Shared program registry
    /// * `program` - Mutable reference to the bounty program
    public entry fun resume_program(
        registry: &mut ProgramRegistry,
        program: &mut BountyProgram,
        ctx: &TxContext
    ) {
        // Only program owner can resume
        assert!(
            bounty_types::project_owner(program) == tx_context::sender(ctx),
            constants::e_not_program_owner()
        );

        // Check not expired
        assert!(
            !bounty_crud::is_expired(program, tx_context::epoch(ctx)),
            constants::e_program_expired()
        );

        bounty_crud::resume(program, ctx);

        // Update registry
        let program_id = object::uid_to_inner(bounty_types::id(program));
        bounty_registry::mark_active(registry, program_id);
    }

    /// Update the Walrus blob ID (when program details change)
    /// 
    /// # Arguments
    /// * `program` - Mutable reference to the bounty program
    /// * `new_blob_id` - New Walrus blob ID
    public entry fun update_program_details(
        program: &mut BountyProgram,
        new_blob_id: vector<u8>,
        ctx: &TxContext
    ) {
        use suiguard::walrus;

        // Only program owner can update
        assert!(
            bounty_types::project_owner(program) == tx_context::sender(ctx),
            constants::e_not_program_owner()
        );

        // Validate new Walrus blob ID
        walrus::assert_valid_blob_id(&new_blob_id);

        bounty_crud::update_walrus_blob(program, new_blob_id);
    }

    // ========== View Functions (No Gas Cost) ==========

    /// Check if a program is currently accepting bug reports
    public fun is_accepting_reports(program: &BountyProgram, ctx: &TxContext): bool {
        bounty_crud::can_accept_reports(program, tx_context::epoch(ctx))
    }

    /// Get available escrow amount (not reserved for pending bugs)
    public fun get_available_funds(program: &BountyProgram): u64 {
        bounty_crud::get_available_escrow(program)
    }

    // ========== Discovery View Functions ==========

    /// Get registry statistics
    public fun get_registry_stats(registry: &ProgramRegistry): (u64, u64) {
        (
            bounty_registry::total_programs(registry),
            bounty_registry::active_programs(registry)
        )
    }

    /// Get detailed information about a program
    public fun get_program_stats(program: &BountyProgram): ProgramInfo {
        bounty_registry::get_program_info(program)
    }

    /// Check if program is registered in discovery
    public fun is_program_registered(registry: &ProgramRegistry, program: &BountyProgram): bool {
        let program_id = object::uid_to_inner(bounty_types::id(program));
        bounty_registry::is_registered(registry, program_id)
    }
}

