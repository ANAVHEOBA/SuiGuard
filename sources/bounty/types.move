/// Bounty Program Data Models
/// Defines all structs and types for the bounty system
module suiguard::bounty_types {
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::TxContext;

    /// Main bounty program object
    /// Holds escrow funds and reward tier configuration
    public struct BountyProgram has key, store {
        id: UID,
        project_owner: address,
        name: vector<u8>,
        description: vector<u8>,
        total_escrow: Balance<SUI>,
        reserved_payouts: u64,                    // Amount reserved for pending bugs
        severity_tiers: VecMap<u8, u64>,          // Severity -> payout amount (in MIST)
        walrus_blob_id: vector<u8>,               // Program details stored on Walrus
        active: bool,
        created_at: u64,
        expires_at: u64,
        // Statistics
        total_reports_submitted: u64,             // Total bug reports received
        total_reports_resolved: u64,              // Total bugs paid out
        total_payouts_made: u64,                  // Total SUI paid out (in MIST)
    }

    // ========== Constructor (package-only) ==========

    public(package) fun new(
        project_owner: address,
        name: vector<u8>,
        description: vector<u8>,
        total_escrow: Balance<SUI>,
        severity_tiers: VecMap<u8, u64>,
        walrus_blob_id: vector<u8>,
        created_at: u64,
        expires_at: u64,
        ctx: &mut TxContext,
    ): BountyProgram {
        BountyProgram {
            id: object::new(ctx),
            project_owner,
            name,
            description,
            total_escrow,
            reserved_payouts: 0,
            severity_tiers,
            walrus_blob_id,
            active: true,
            created_at,
            expires_at,
            total_reports_submitted: 0,
            total_reports_resolved: 0,
            total_payouts_made: 0,
        }
    }

    // ========== Getters ==========

    public fun id(program: &BountyProgram): &UID {
        &program.id
    }

    public fun project_owner(program: &BountyProgram): address {
        program.project_owner
    }

    public fun name(program: &BountyProgram): &vector<u8> {
        &program.name
    }

    public fun description(program: &BountyProgram): &vector<u8> {
        &program.description
    }

    public fun total_escrow_value(program: &BountyProgram): u64 {
        balance::value(&program.total_escrow)
    }

    public fun reserved_payouts(program: &BountyProgram): u64 {
        program.reserved_payouts
    }

    public fun available_escrow(program: &BountyProgram): u64 {
        balance::value(&program.total_escrow) - program.reserved_payouts
    }

    public fun is_active(program: &BountyProgram): bool {
        program.active
    }

    public fun created_at(program: &BountyProgram): u64 {
        program.created_at
    }

    public fun expires_at(program: &BountyProgram): u64 {
        program.expires_at
    }

    public fun walrus_blob_id(program: &BountyProgram): &vector<u8> {
        &program.walrus_blob_id
    }

    public fun severity_tiers(program: &BountyProgram): &VecMap<u8, u64> {
        &program.severity_tiers
    }

    public fun get_tier_amount(program: &BountyProgram, severity: u8): u64 {
        *vec_map::get(&program.severity_tiers, &severity)
    }

    public fun get_severity_payout(program: &BountyProgram, severity: u8): u64 {
        *vec_map::get(&program.severity_tiers, &severity)
    }

    public fun total_reports_submitted(program: &BountyProgram): u64 {
        program.total_reports_submitted
    }

    public fun total_reports_resolved(program: &BountyProgram): u64 {
        program.total_reports_resolved
    }

    public fun total_payouts_made(program: &BountyProgram): u64 {
        program.total_payouts_made
    }

    // ========== Mutable Getters (package-only) ==========

    public(package) fun escrow_mut(program: &mut BountyProgram): &mut Balance<SUI> {
        &mut program.total_escrow
    }

    public(package) fun severity_tiers_mut(program: &mut BountyProgram): &mut VecMap<u8, u64> {
        &mut program.severity_tiers
    }

    public(package) fun set_active(program: &mut BountyProgram, active: bool) {
        program.active = active;
    }

    public(package) fun add_reserved_payout(program: &mut BountyProgram, amount: u64) {
        program.reserved_payouts = program.reserved_payouts + amount;
    }

    public(package) fun subtract_reserved_payout(program: &mut BountyProgram, amount: u64) {
        program.reserved_payouts = program.reserved_payouts - amount;
    }

    public(package) fun set_walrus_blob_id(program: &mut BountyProgram, blob_id: vector<u8>) {
        program.walrus_blob_id = blob_id;
    }

    public(package) fun increment_reports_submitted(program: &mut BountyProgram) {
        program.total_reports_submitted = program.total_reports_submitted + 1;
    }

    public(package) fun increment_reports_resolved(program: &mut BountyProgram) {
        program.total_reports_resolved = program.total_reports_resolved + 1;
    }

    public(package) fun add_payout(program: &mut BountyProgram, amount: u64) {
        program.total_payouts_made = program.total_payouts_made + amount;
    }
}
