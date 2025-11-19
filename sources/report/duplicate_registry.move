/// Duplicate Detection Registry
/// Maintains a shared registry to detect duplicate vulnerability reports
module suiguard::duplicate_registry {
    use std::option::{Self, Option};
    use sui::object::{Self, ID, UID};
    use sui::table::{Self, Table};
    use sui::tx_context::TxContext;

    // ========== Error Codes ==========

    /// Duplicate vulnerability signature already registered
    const E_DUPLICATE_SIGNATURE: u64 = 2020;

    /// Signature not found in registry
    const E_SIGNATURE_NOT_FOUND: u64 = 2021;

    // ========== Data Structures ==========

    /// Shared registry that maps vulnerability signatures to original report IDs
    /// This allows us to detect duplicate submissions across the platform
    public struct DuplicateRegistry has key {
        id: UID,
        /// Maps vulnerability_hash -> original report ID
        /// The hash should be computed from program_id + vulnerability signature
        signatures: Table<vector<u8>, ID>,
        /// Total number of unique vulnerabilities registered
        total_registered: u64,
        /// Total number of duplicates detected
        total_duplicates_detected: u64,
    }

    // ========== Constructor ==========

    /// Create a new duplicate registry (called once during module init)
    fun new(ctx: &mut TxContext): DuplicateRegistry {
        DuplicateRegistry {
            id: object::new(ctx),
            signatures: table::new(ctx),
            total_registered: 0,
            total_duplicates_detected: 0,
        }
    }

    /// Initialize and share the registry (called from init)
    public(package) fun create_and_share(ctx: &mut TxContext) {
        use sui::transfer;
        let registry = new(ctx);
        transfer::share_object(registry);
    }

    // ========== Registry Operations ==========

    /// Check if a vulnerability signature is already registered
    /// Returns Some(original_report_id) if duplicate, None if unique
    public fun check_duplicate(
        registry: &DuplicateRegistry,
        vulnerability_hash: &vector<u8>,
    ): Option<ID> {
        if (table::contains(&registry.signatures, *vulnerability_hash)) {
            let original_id = *table::borrow(&registry.signatures, *vulnerability_hash);
            option::some(original_id)
        } else {
            option::none()
        }
    }

    /// Register a new vulnerability signature with its report ID
    /// This should be called when a report is accepted as valid (not duplicate)
    ///
    /// # Arguments
    /// * `registry` - The shared duplicate registry
    /// * `vulnerability_hash` - Hash of the vulnerability signature (program_id + vuln details)
    /// * `report_id` - ID of the original report
    ///
    /// # Panics
    /// Panics if the signature is already registered (duplicate)
    public(package) fun register_signature(
        registry: &mut DuplicateRegistry,
        vulnerability_hash: vector<u8>,
        report_id: ID,
    ) {
        // Ensure this is not a duplicate
        assert!(
            !table::contains(&registry.signatures, vulnerability_hash),
            E_DUPLICATE_SIGNATURE
        );

        // Register the signature
        table::add(&mut registry.signatures, vulnerability_hash, report_id);
        registry.total_registered = registry.total_registered + 1;
    }

    /// Get the original report ID for a vulnerability signature
    /// Used when marking a report as duplicate to link to the original
    ///
    /// # Arguments
    /// * `registry` - The shared duplicate registry
    /// * `vulnerability_hash` - Hash of the vulnerability signature
    ///
    /// # Returns
    /// The ID of the original report that first reported this vulnerability
    ///
    /// # Panics
    /// Panics if the signature is not found in the registry
    public fun get_original_report(
        registry: &DuplicateRegistry,
        vulnerability_hash: &vector<u8>,
    ): ID {
        assert!(
            table::contains(&registry.signatures, *vulnerability_hash),
            E_SIGNATURE_NOT_FOUND
        );
        *table::borrow(&registry.signatures, *vulnerability_hash)
    }

    /// Record that a duplicate was detected (for statistics)
    public(package) fun increment_duplicates(registry: &mut DuplicateRegistry) {
        registry.total_duplicates_detected = registry.total_duplicates_detected + 1;
    }

    /// Remove a signature from the registry
    /// This should only be called if the original report is withdrawn or rejected
    public(package) fun unregister_signature(
        registry: &mut DuplicateRegistry,
        vulnerability_hash: &vector<u8>,
    ) {
        if (table::contains(&registry.signatures, *vulnerability_hash)) {
            table::remove(&mut registry.signatures, *vulnerability_hash);
            if (registry.total_registered > 0) {
                registry.total_registered = registry.total_registered - 1;
            };
        };
    }

    // ========== View Functions ==========

    /// Check if a signature is registered
    public fun is_registered(
        registry: &DuplicateRegistry,
        vulnerability_hash: &vector<u8>,
    ): bool {
        table::contains(&registry.signatures, *vulnerability_hash)
    }

    /// Get total number of unique vulnerabilities registered
    public fun total_registered(registry: &DuplicateRegistry): u64 {
        registry.total_registered
    }

    /// Get total number of duplicates detected
    public fun total_duplicates_detected(registry: &DuplicateRegistry): u64 {
        registry.total_duplicates_detected
    }

    /// Get registry statistics
    public fun get_stats(registry: &DuplicateRegistry): (u64, u64) {
        (registry.total_registered, registry.total_duplicates_detected)
    }

    // ========== Error Code Getters ==========

    public fun e_duplicate_signature(): u64 { E_DUPLICATE_SIGNATURE }
    public fun e_signature_not_found(): u64 { E_SIGNATURE_NOT_FOUND }
}
