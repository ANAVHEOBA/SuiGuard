/// CRUD operations for bounty programs
module suiguard::bounty_crud {
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::sui::SUI;
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::TxContext;
    use suiguard::bounty_types::{Self, BountyProgram};
    use suiguard::bounty_validation;
    use suiguard::bounty_events;
    use suiguard::constants;

    // ========== Create Operations ==========

    /// Create a new bounty program
    public(package) fun create(
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
    ): BountyProgram {
        // Validate inputs
        bounty_validation::validate_program_name(&name);
        let escrow_value = coin::value(&escrow);
        bounty_validation::validate_escrow_amount(escrow_value);
        bounty_validation::validate_tier_amounts(critical_amount, high_amount, medium_amount, low_amount);

        // Validate escrow is sufficient to cover at least the highest tier payout
        assert!(
            escrow_value >= critical_amount,
            constants::e_escrow_too_low()
        );

        // Create severity tiers
        let mut tiers = vec_map::empty<u8, u64>();
        vec_map::insert(&mut tiers, constants::severity_critical(), critical_amount);
        vec_map::insert(&mut tiers, constants::severity_high(), high_amount);
        vec_map::insert(&mut tiers, constants::severity_medium(), medium_amount);
        vec_map::insert(&mut tiers, constants::severity_low(), low_amount);
        vec_map::insert(&mut tiers, constants::severity_informational(), informational_amount);

        // Validate tier configuration
        bounty_validation::validate_tier_map(&tiers);

        // Calculate expiry
        let current_epoch = tx_context::epoch(ctx);
        let expires_at = current_epoch + duration_days;
        bounty_validation::validate_expiry(current_epoch, expires_at);

        // Create program object
        let project_owner = tx_context::sender(ctx);

        let program = bounty_types::new(
            project_owner,
            name,
            description,
            coin::into_balance(escrow),
            tiers,
            walrus_blob_id,
            current_epoch,
            expires_at,
            ctx,
        );

        // Emit event
        let program_id = object::uid_to_inner(bounty_types::id(&program));
        bounty_events::emit_program_created(
            program_id,
            project_owner,
            *bounty_types::name(&program),
            escrow_value,
            current_epoch,
            expires_at,
        );

        program
    }

    // ========== Update Operations ==========

    /// Add additional funds to a bounty program
    public(package) fun fund(
        program: &mut BountyProgram,
        additional_funds: Coin<SUI>,
    ) {
        let amount = coin::value(&additional_funds);
        let escrow = bounty_types::escrow_mut(program);
        balance::join(escrow, coin::into_balance(additional_funds));

        let new_total = bounty_types::total_escrow_value(program);

        bounty_events::emit_program_funded(
            object::uid_to_inner(bounty_types::id(program)),
            amount,
            new_total,
        );
    }

    /// Update severity tier amounts
    public(package) fun update_tiers(
        program: &mut BountyProgram,
        critical: u64,
        high: u64,
        medium: u64,
        low: u64,
        informational: u64,
    ) {
        // Validate new amounts
        bounty_validation::validate_tier_amounts(critical, high, medium, low);

        let tiers = bounty_types::severity_tiers_mut(program);

        // Update all tiers
        *vec_map::get_mut(tiers, &constants::severity_critical()) = critical;
        *vec_map::get_mut(tiers, &constants::severity_high()) = high;
        *vec_map::get_mut(tiers, &constants::severity_medium()) = medium;
        *vec_map::get_mut(tiers, &constants::severity_low()) = low;
        *vec_map::get_mut(tiers, &constants::severity_informational()) = informational;

        bounty_events::emit_tiers_updated(
            object::uid_to_inner(bounty_types::id(program)),
            critical,
            high,
            medium,
            low,
            informational,
        );
    }

    /// Pause a bounty program
    public(package) fun pause(
        program: &mut BountyProgram,
        ctx: &TxContext,
    ) {
        assert!(bounty_types::is_active(program), constants::e_program_not_active());
        bounty_types::set_active(program, false);

        bounty_events::emit_program_paused(
            object::uid_to_inner(bounty_types::id(program)),
            tx_context::sender(ctx),
        );
    }

    /// Resume a paused bounty program
    public(package) fun resume(
        program: &mut BountyProgram,
        ctx: &TxContext,
    ) {
        assert!(!bounty_types::is_active(program), constants::e_program_not_active());
        bounty_types::set_active(program, true);

        bounty_events::emit_program_resumed(
            object::uid_to_inner(bounty_types::id(program)),
            tx_context::sender(ctx),
        );
    }

    /// Update Walrus blob ID (e.g., when program details change)
    public(package) fun update_walrus_blob(
        program: &mut BountyProgram,
        new_blob_id: vector<u8>,
    ) {
        let old_blob_id = *bounty_types::walrus_blob_id(program);
        bounty_types::set_walrus_blob_id(program, new_blob_id);

        bounty_events::emit_walrus_blob_updated(
            object::uid_to_inner(bounty_types::id(program)),
            old_blob_id,
            *bounty_types::walrus_blob_id(program),
        );
    }

    // ========== Query Operations ==========

    /// Check if program has expired
    public fun is_expired(program: &BountyProgram, current_epoch: u64): bool {
        current_epoch >= bounty_types::expires_at(program)
    }

    /// Check if program can accept new bug reports
    public fun can_accept_reports(program: &BountyProgram, current_epoch: u64): bool {
        bounty_types::is_active(program) && !is_expired(program, current_epoch)
    }

    /// Get available escrow (not reserved for pending payouts)
    public fun get_available_escrow(program: &BountyProgram): u64 {
        bounty_types::available_escrow(program)
    }
}
