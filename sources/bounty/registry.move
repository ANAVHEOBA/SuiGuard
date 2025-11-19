/// Program Registry for Discovery
/// Maintains a shared registry of all bounty programs for querying
module suiguard::bounty_registry {
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::TxContext;
    use suiguard::bounty_types::BountyProgram;

    /// Shared registry that tracks all bounty programs
    public struct ProgramRegistry has key {
        id: UID,
        /// Maps program ID to program owner address for quick lookups
        programs: Table<ID, address>,
        /// Total number of programs ever created
        total_programs: u64,
        /// Number of currently active programs
        active_programs: u64,
    }

    /// Program metadata for discovery queries
    public struct ProgramInfo has copy, drop, store {
        program_id: ID,
        owner: address,
        name: vector<u8>,
        total_escrow: u64,
        available_escrow: u64,
        critical_payout: u64,
        high_payout: u64,
        medium_payout: u64,
        low_payout: u64,
        is_active: bool,
        total_reports: u64,
        total_resolved: u64,
        total_payouts: u64,
        created_at: u64,
        expires_at: u64,
    }

    // ========== Constructor ==========

    /// Create a new program registry (called once during module init)
    fun new(ctx: &mut TxContext): ProgramRegistry {
        ProgramRegistry {
            id: object::new(ctx),
            programs: table::new(ctx),
            total_programs: 0,
            active_programs: 0,
        }
    }

    /// Initialize and share the registry (called from init)
    public(package) fun create_and_share(ctx: &mut TxContext) {
        use sui::transfer;
        let registry = new(ctx);
        transfer::share_object(registry);
    }

    // ========== Registry Management ==========

    /// Register a new program in the registry
    public(package) fun register_program(
        registry: &mut ProgramRegistry,
        program_id: ID,
        owner: address,
    ) {
        table::add(&mut registry.programs, program_id, owner);
        registry.total_programs = registry.total_programs + 1;
        registry.active_programs = registry.active_programs + 1;
    }

    /// Mark a program as inactive (when paused or expired)
    public(package) fun mark_inactive(
        registry: &mut ProgramRegistry,
        program_id: ID,
    ) {
        assert!(table::contains(&registry.programs, program_id), 0);
        if (registry.active_programs > 0) {
            registry.active_programs = registry.active_programs - 1;
        };
    }

    /// Mark a program as active (when resumed)
    public(package) fun mark_active(
        registry: &mut ProgramRegistry,
        program_id: ID,
    ) {
        assert!(table::contains(&registry.programs, program_id), 0);
        registry.active_programs = registry.active_programs + 1;
    }

    // ========== View Functions ==========

    /// Check if a program is registered
    public fun is_registered(registry: &ProgramRegistry, program_id: ID): bool {
        table::contains(&registry.programs, program_id)
    }

    /// Get owner of a registered program
    public fun get_program_owner(registry: &ProgramRegistry, program_id: ID): address {
        *table::borrow(&registry.programs, program_id)
    }

    /// Get total number of programs
    public fun total_programs(registry: &ProgramRegistry): u64 {
        registry.total_programs
    }

    /// Get number of active programs
    public fun active_programs(registry: &ProgramRegistry): u64 {
        registry.active_programs
    }

    /// Extract program information for discovery
    public fun get_program_info(program: &BountyProgram): ProgramInfo {
        use suiguard::bounty_types;
        use suiguard::constants;

        ProgramInfo {
            program_id: object::uid_to_inner(bounty_types::id(program)),
            owner: bounty_types::project_owner(program),
            name: *bounty_types::name(program),
            total_escrow: bounty_types::total_escrow_value(program),
            available_escrow: bounty_types::available_escrow(program),
            critical_payout: bounty_types::get_tier_amount(program, constants::severity_critical()),
            high_payout: bounty_types::get_tier_amount(program, constants::severity_high()),
            medium_payout: bounty_types::get_tier_amount(program, constants::severity_medium()),
            low_payout: bounty_types::get_tier_amount(program, constants::severity_low()),
            is_active: bounty_types::is_active(program),
            total_reports: bounty_types::total_reports_submitted(program),
            total_resolved: bounty_types::total_reports_resolved(program),
            total_payouts: bounty_types::total_payouts_made(program),
            created_at: bounty_types::created_at(program),
            expires_at: bounty_types::expires_at(program),
        }
    }

    // ========== ProgramInfo Getters ==========

    public fun info_program_id(info: &ProgramInfo): ID {
        info.program_id
    }

    public fun info_owner(info: &ProgramInfo): address {
        info.owner
    }

    public fun info_name(info: &ProgramInfo): &vector<u8> {
        &info.name
    }

    public fun info_total_escrow(info: &ProgramInfo): u64 {
        info.total_escrow
    }

    public fun info_available_escrow(info: &ProgramInfo): u64 {
        info.available_escrow
    }

    public fun info_critical_payout(info: &ProgramInfo): u64 {
        info.critical_payout
    }

    public fun info_high_payout(info: &ProgramInfo): u64 {
        info.high_payout
    }

    public fun info_is_active(info: &ProgramInfo): bool {
        info.is_active
    }

    public fun info_total_reports(info: &ProgramInfo): u64 {
        info.total_reports
    }

    public fun info_total_resolved(info: &ProgramInfo): u64 {
        info.total_resolved
    }

    public fun info_total_payouts(info: &ProgramInfo): u64 {
        info.total_payouts
    }
}
