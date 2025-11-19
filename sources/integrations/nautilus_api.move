/// Nautilus TEE Attestation API
/// Public entry functions for TEE attestation submission and verification
module suiguard::nautilus_api {
    use std::option;
    use sui::transfer;
    use sui::object;
    use sui::tx_context::TxContext;
    use suiguard::nautilus_types::{Self, Attestation};
    use suiguard::nautilus_registry::{Self, EnclaveRegistry, AdminCap};
    use suiguard::nautilus_validation;
    use suiguard::nautilus_events;

    // ========== Attestation Submission ==========

    /// Submit a new TEE attestation for proof-of-concept verification
    ///
    /// # Arguments
    /// * `tee_type` - Type of TEE (0=SGX, 1=TDX)
    /// * `quote` - Raw attestation quote from Nautilus enclave
    /// * `enclave_measurement` - MRENCLAVE (SGX) or MRTD (TDX)
    /// * `signer_measurement` - MRSIGNER for SGX
    /// * `signature` - Cryptographic signature over attestation data
    /// * `public_key` - Public key for signature verification
    /// * `nonce` - Unique nonce for replay attack prevention
    /// * `bug_report_id` - Optional ID of associated bug report
    ///
    /// # Returns
    /// Creates an Attestation object and transfers it to the researcher
    public entry fun submit_attestation(
        registry: &EnclaveRegistry,
        tee_type: u8,
        quote: vector<u8>,
        enclave_measurement: vector<u8>,
        signer_measurement: vector<u8>,
        signature: vector<u8>,
        public_key: vector<u8>,
        nonce: vector<u8>,
        bug_report_id: Option<address>,
        ctx: &mut TxContext,
    ) {
        let researcher = tx_context::sender(ctx);
        let timestamp = tx_context::epoch(ctx);

        // Create attestation object
        let attestation = nautilus_types::new_attestation(
            tee_type,
            quote,
            enclave_measurement,
            signer_measurement,
            signature,
            public_key,
            timestamp,
            nonce,
            researcher,
            bug_report_id,
            ctx,
        );

        // Emit submission event
        let attestation_id = object::uid_to_inner(nautilus_types::id(&attestation));
        nautilus_events::emit_attestation_submitted(
            attestation_id,
            researcher,
            tee_type,
            *nautilus_types::enclave_measurement(&attestation),
            timestamp,
            bug_report_id,
        );

        // Transfer attestation to researcher
        transfer::public_transfer(attestation, researcher);
    }

    /// Verify a submitted attestation
    ///
    /// # Arguments
    /// * `attestation` - Mutable reference to the attestation to verify
    /// * `registry` - Enclave registry for trusted enclave validation
    /// * `exploit_confirmed` - Result from TEE: was exploit confirmed?
    ///
    /// # Note
    /// This function validates the attestation and marks it as verified/rejected
    public entry fun verify_attestation(
        attestation: &mut Attestation,
        registry: &EnclaveRegistry,
        exploit_confirmed: bool,
        ctx: &TxContext,
    ) {
        // Perform full validation
        nautilus_validation::assert_valid_attestation(attestation, registry, ctx);

        // Mark as verified
        let current_epoch = tx_context::epoch(ctx);
        nautilus_types::set_status(attestation, nautilus_types::status_verified());
        nautilus_types::set_exploit_confirmed(attestation, exploit_confirmed);
        nautilus_types::set_verified_at(attestation, current_epoch);

        // Emit verification event
        let attestation_id = object::uid_to_inner(nautilus_types::id(attestation));
        nautilus_events::emit_attestation_verified(
            attestation_id,
            nautilus_types::researcher(attestation),
            exploit_confirmed,
            current_epoch,
        );
    }

    /// Reject an attestation (failed validation)
    ///
    /// # Arguments
    /// * `attestation` - Mutable reference to the attestation to reject
    /// * `reason` - Human-readable rejection reason
    public entry fun reject_attestation(
        attestation: &mut Attestation,
        reason: vector<u8>,
        ctx: &TxContext,
    ) {
        // Mark as rejected
        let current_epoch = tx_context::epoch(ctx);
        nautilus_types::set_status(attestation, nautilus_types::status_rejected());
        nautilus_types::set_verified_at(attestation, current_epoch);

        // Emit rejection event
        let attestation_id = object::uid_to_inner(nautilus_types::id(attestation));
        nautilus_events::emit_attestation_rejected(
            attestation_id,
            nautilus_types::researcher(attestation),
            reason,
        );
    }

    /// Link an attestation to a bug report
    ///
    /// # Arguments
    /// * `attestation` - Mutable reference to the attestation
    /// * `report_id` - ID of the bug report to link
    public entry fun link_to_bug_report(
        attestation: &mut Attestation,
        report_id: address,
        ctx: &TxContext,
    ) {
        // Only researcher can link their attestation
        assert!(
            nautilus_types::researcher(attestation) == tx_context::sender(ctx),
            0 // E_NOT_RESEARCHER
        );

        nautilus_types::set_bug_report_id(attestation, report_id);
    }

    // ========== Enclave Registry Management ==========

    /// Add a trusted Nautilus enclave to the whitelist
    ///
    /// # Arguments
    /// * `registry` - Mutable reference to the enclave registry
    /// * `admin_cap` - Admin capability
    /// * `measurement` - Enclave measurement hash (MRENCLAVE/MRTD)
    /// * `description` - Human-readable description
    public entry fun add_trusted_enclave(
        registry: &mut EnclaveRegistry,
        admin_cap: &AdminCap,
        measurement: vector<u8>,
        description: vector<u8>,
        ctx: &TxContext,
    ) {
        nautilus_registry::add_trusted_enclave(
            registry,
            admin_cap,
            measurement,
            description,
            ctx,
        );

        // Emit event
        let current_epoch = tx_context::epoch(ctx);
        nautilus_events::emit_enclave_added(
            measurement,
            description,
            current_epoch,
        );
    }

    /// Revoke trust for an enclave
    ///
    /// # Arguments
    /// * `registry` - Mutable reference to the enclave registry
    /// * `admin_cap` - Admin capability
    /// * `measurement` - Enclave measurement to revoke
    public entry fun revoke_enclave(
        registry: &mut EnclaveRegistry,
        admin_cap: &AdminCap,
        measurement: vector<u8>,
        ctx: &TxContext,
    ) {
        nautilus_registry::revoke_enclave(registry, admin_cap, measurement);

        // Emit event
        let current_epoch = tx_context::epoch(ctx);
        nautilus_events::emit_enclave_revoked(measurement, current_epoch);
    }

    /// Restore trust for a previously revoked enclave
    ///
    /// # Arguments
    /// * `registry` - Mutable reference to the enclave registry
    /// * `admin_cap` - Admin capability
    /// * `measurement` - Enclave measurement to restore
    public entry fun restore_enclave(
        registry: &mut EnclaveRegistry,
        admin_cap: &AdminCap,
        measurement: vector<u8>,
        ctx: &TxContext,
    ) {
        nautilus_registry::restore_enclave(registry, admin_cap, measurement);

        // Emit event
        let current_epoch = tx_context::epoch(ctx);
        nautilus_events::emit_enclave_restored(measurement, current_epoch);
    }

    // ========== View Functions ==========

    /// Check if an attestation is verified
    public fun is_verified(attestation: &Attestation): bool {
        nautilus_types::is_verified(attestation)
    }

    /// Check if an enclave is trusted
    public fun is_trusted_enclave(
        registry: &EnclaveRegistry,
        measurement: &vector<u8>,
    ): bool {
        nautilus_registry::is_trusted_enclave(registry, measurement)
    }

    /// Get registry statistics
    public fun get_registry_stats(registry: &EnclaveRegistry): (u64, u64) {
        nautilus_registry::get_stats(registry)
    }
}
