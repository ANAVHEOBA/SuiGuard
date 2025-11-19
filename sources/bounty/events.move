/// Event definitions for bounty program operations
module suiguard::bounty_events {
    use sui::event;
    use sui::object::ID;

    // ========== Event Structs ==========

    /// Emitted when a new bounty program is created
    public struct ProgramCreated has copy, drop {
        program_id: ID,
        project_owner: address,
        name: vector<u8>,
        total_escrow: u64,
        created_at: u64,
        expires_at: u64,
    }

    /// Emitted when a bounty program receives additional funding
    public struct ProgramFunded has copy, drop {
        program_id: ID,
        amount: u64,
        new_total_escrow: u64,
    }

    /// Emitted when severity tier amounts are updated
    public struct TiersUpdated has copy, drop {
        program_id: ID,
        critical: u64,
        high: u64,
        medium: u64,
        low: u64,
        informational: u64,
    }

    /// Emitted when a program is paused
    public struct ProgramPaused has copy, drop {
        program_id: ID,
        paused_by: address,
    }

    /// Emitted when a program is resumed
    public struct ProgramResumed has copy, drop {
        program_id: ID,
        resumed_by: address,
    }

    /// Emitted when Walrus blob ID is updated
    public struct WalrusBlobUpdated has copy, drop {
        program_id: ID,
        old_blob_id: vector<u8>,
        new_blob_id: vector<u8>,
    }

    // ========== Event Emitters ==========

    public(package) fun emit_program_created(
        program_id: ID,
        project_owner: address,
        name: vector<u8>,
        total_escrow: u64,
        created_at: u64,
        expires_at: u64,
    ) {
        event::emit(ProgramCreated {
            program_id,
            project_owner,
            name,
            total_escrow,
            created_at,
            expires_at,
        });
    }

    public(package) fun emit_program_funded(
        program_id: ID,
        amount: u64,
        new_total_escrow: u64,
    ) {
        event::emit(ProgramFunded {
            program_id,
            amount,
            new_total_escrow,
        });
    }

    public(package) fun emit_tiers_updated(
        program_id: ID,
        critical: u64,
        high: u64,
        medium: u64,
        low: u64,
        informational: u64,
    ) {
        event::emit(TiersUpdated {
            program_id,
            critical,
            high,
            medium,
            low,
            informational,
        });
    }

    public(package) fun emit_program_paused(
        program_id: ID,
        paused_by: address,
    ) {
        event::emit(ProgramPaused {
            program_id,
            paused_by,
        });
    }

    public(package) fun emit_program_resumed(
        program_id: ID,
        resumed_by: address,
    ) {
        event::emit(ProgramResumed {
            program_id,
            resumed_by,
        });
    }

    public(package) fun emit_walrus_blob_updated(
        program_id: ID,
        old_blob_id: vector<u8>,
        new_blob_id: vector<u8>,
    ) {
        event::emit(WalrusBlobUpdated {
            program_id,
            old_blob_id,
            new_blob_id,
        });
    }
}
