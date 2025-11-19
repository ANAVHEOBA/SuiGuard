/// Trusted Enclave Registry
/// Manages whitelist of legitimate Nautilus TEE enclaves
module suiguard::nautilus_registry {
    use sui::object::{Self, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::TxContext;
    use sui::vec_map::{Self, VecMap};
    use suiguard::nautilus_types::{Self, TrustedEnclave};

    /// Shared registry of trusted TEE enclaves
    public struct EnclaveRegistry has key {
        id: UID,
        /// Maps enclave measurement hash -> TrustedEnclave
        /// Key is a hash of the measurement for efficient lookups
        enclaves: VecMap<vector<u8>, TrustedEnclave>,
        /// Admin addresses authorized to manage the registry
        admins: Table<address, bool>,
        /// Total enclaves ever added
        total_enclaves: u64,
        /// Currently active enclaves
        active_enclaves: u64,
    }

    /// Admin capability for managing the enclave registry
    public struct AdminCap has key, store {
        id: UID,
    }

    // ========== Constructor ==========

    /// Create a new enclave registry
    fun new(ctx: &mut TxContext): EnclaveRegistry {
        EnclaveRegistry {
            id: object::new(ctx),
            enclaves: vec_map::empty(),
            admins: table::new(ctx),
            total_enclaves: 0,
            active_enclaves: 0,
        }
    }

    /// Initialize and share the registry
    public(package) fun create_and_share(ctx: &mut TxContext) {
        use sui::transfer;
        let registry = new(ctx);
        transfer::share_object(registry);

        // Create admin capability for deployer
        let admin_cap = AdminCap {
            id: object::new(ctx),
        };
        transfer::transfer(admin_cap, tx_context::sender(ctx));
    }

    // ========== Admin Management ==========

    /// Add an admin to the registry
    public fun add_admin(
        registry: &mut EnclaveRegistry,
        _admin_cap: &AdminCap,
        new_admin: address,
    ) {
        if (!table::contains(&registry.admins, new_admin)) {
            table::add(&mut registry.admins, new_admin, true);
        };
    }

    /// Remove an admin from the registry
    public fun remove_admin(
        registry: &mut EnclaveRegistry,
        _admin_cap: &AdminCap,
        admin: address,
    ) {
        if (table::contains(&registry.admins, admin)) {
            table::remove(&mut registry.admins, admin);
        };
    }

    /// Check if address is an admin
    public fun is_admin(registry: &EnclaveRegistry, addr: address): bool {
        table::contains(&registry.admins, addr)
    }

    // ========== Enclave Management ==========

    /// Add a trusted enclave to the whitelist
    public fun add_trusted_enclave(
        registry: &mut EnclaveRegistry,
        _admin_cap: &AdminCap,
        measurement: vector<u8>,
        description: vector<u8>,
        ctx: &TxContext,
    ) {
        let current_epoch = tx_context::epoch(ctx);
        let enclave = nautilus_types::new_trusted_enclave(
            measurement,
            description,
            current_epoch,
        );

        // Check if enclave already exists
        if (!vec_map::contains(&registry.enclaves, &measurement)) {
            vec_map::insert(&mut registry.enclaves, measurement, enclave);
            registry.total_enclaves = registry.total_enclaves + 1;
            registry.active_enclaves = registry.active_enclaves + 1;
        };
    }

    /// Revoke trust for an enclave (deactivate)
    public fun revoke_enclave(
        registry: &mut EnclaveRegistry,
        _admin_cap: &AdminCap,
        measurement: vector<u8>,
    ) {
        if (vec_map::contains(&registry.enclaves, &measurement)) {
            let enclave = vec_map::get_mut(&mut registry.enclaves, &measurement);

            if (nautilus_types::enclave_is_active(enclave)) {
                nautilus_types::deactivate_enclave(enclave);
                if (registry.active_enclaves > 0) {
                    registry.active_enclaves = registry.active_enclaves - 1;
                };
            };
        };
    }

    /// Restore trust for a previously revoked enclave
    public fun restore_enclave(
        registry: &mut EnclaveRegistry,
        _admin_cap: &AdminCap,
        measurement: vector<u8>,
    ) {
        if (vec_map::contains(&registry.enclaves, &measurement)) {
            let enclave = vec_map::get_mut(&mut registry.enclaves, &measurement);

            if (!nautilus_types::enclave_is_active(enclave)) {
                nautilus_types::activate_enclave(enclave);
                registry.active_enclaves = registry.active_enclaves + 1;
            };
        };
    }

    // ========== View Functions ==========

    /// Check if an enclave measurement is trusted and active
    public fun is_trusted_enclave(
        registry: &EnclaveRegistry,
        measurement: &vector<u8>,
    ): bool {
        if (!vec_map::contains(&registry.enclaves, measurement)) {
            return false
        };

        let enclave = vec_map::get(&registry.enclaves, measurement);
        nautilus_types::enclave_is_active(enclave)
    }

    /// Get enclave details if it exists
    public fun get_enclave(
        registry: &EnclaveRegistry,
        measurement: &vector<u8>,
    ): &TrustedEnclave {
        vec_map::get(&registry.enclaves, measurement)
    }

    /// Get registry statistics
    public fun get_stats(registry: &EnclaveRegistry): (u64, u64) {
        (registry.total_enclaves, registry.active_enclaves)
    }

    /// Get total number of enclaves
    public fun total_enclaves(registry: &EnclaveRegistry): u64 {
        registry.total_enclaves
    }

    /// Get number of active enclaves
    public fun active_enclaves(registry: &EnclaveRegistry): u64 {
        registry.active_enclaves
    }
}
