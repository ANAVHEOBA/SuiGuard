/// Nautilus TEE Attestation Validation
/// Cryptographic verification and business logic validation
module suiguard::nautilus_validation {
    use std::vector;
    use sui::ecdsa_k1;
    use sui::hash;
    use sui::bcs;
    use sui::tx_context::TxContext;
    use suiguard::nautilus_types::Attestation;
    use suiguard::nautilus_registry::EnclaveRegistry;
    use suiguard::constants;

    /// Maximum age of attestation in epochs (24 hours ≈ 24 epochs on Sui)
    const MAX_ATTESTATION_AGE: u64 = 24;

    /// Error codes (3100-3199 range for attestation errors)
    const E_ATTESTATION_EXPIRED: u64 = 3101;
    const E_INVALID_SIGNATURE: u64 = 3102;
    const E_UNTRUSTED_ENCLAVE: u64 = 3103;
    const E_ATTESTATION_TOO_NEW: u64 = 3104;
    const E_INVALID_TEE_TYPE: u64 = 3105;

    // ========== Validation Functions ==========

    /// Validate attestation timestamp (must be within 24 hours)
    public fun validate_timestamp(
        attestation_timestamp: u64,
        current_epoch: u64,
    ): bool {
        // Check if attestation is too old
        if (current_epoch > attestation_timestamp) {
            let age = current_epoch - attestation_timestamp;
            if (age > MAX_ATTESTATION_AGE) {
                return false
            };
        };

        // Check if attestation is from the future (clock skew protection)
        if (attestation_timestamp > current_epoch + 1) {
            return false
        };

        true
    }

    /// Verify cryptographic signature on attestation
    /// Uses secp256k1 ECDSA signature verification
    public fun verify_signature(
        attestation: &Attestation,
    ): bool {
        use suiguard::nautilus_types;

        // Construct message to verify (quote + enclave_measurement + timestamp + nonce)
        let mut message_bytes = vector::empty<u8>();
        vector::append(&mut message_bytes, *nautilus_types::quote(attestation));
        vector::append(&mut message_bytes, *nautilus_types::enclave_measurement(attestation));

        // Add timestamp as bytes
        let timestamp_bytes = bcs::to_bytes(&nautilus_types::timestamp(attestation));
        vector::append(&mut message_bytes, timestamp_bytes);

        vector::append(&mut message_bytes, *nautilus_types::nonce(attestation));

        // Hash the message
        let message_hash = hash::keccak256(&message_bytes);

        // Verify signature using secp256k1
        let signature = nautilus_types::signature(attestation);
        let public_key = nautilus_types::public_key(attestation);

        // Signature should be 64 bytes (r,s), public key should be 33 bytes (compressed)
        if (vector::length(signature) != 64) {
            return false
        };

        if (vector::length(public_key) != 33) {
            return false
        };

        // Perform ECDSA verification
        // Hash function: 1 = Keccak256 (used for Ethereum-compatible signatures)
        ecdsa_k1::secp256k1_verify(
            signature,
            public_key,
            &message_hash,
            1, // Keccak256 hash function
        )
    }

    /// Validate enclave measurement against trusted registry
    public fun validate_enclave_measurement(
        attestation: &Attestation,
        registry: &EnclaveRegistry,
    ): bool {
        use suiguard::nautilus_types;
        use suiguard::nautilus_registry;

        let measurement = nautilus_types::enclave_measurement(attestation);
        nautilus_registry::is_trusted_enclave(registry, measurement)
    }

    /// Full attestation validation
    /// Returns true if all checks pass
    public fun validate_attestation(
        attestation: &Attestation,
        registry: &EnclaveRegistry,
        ctx: &TxContext,
    ): bool {
        use suiguard::nautilus_types;

        // 1. Check timestamp (not expired, not too new)
        let current_epoch = tx_context::epoch(ctx);
        if (!validate_timestamp(nautilus_types::timestamp(attestation), current_epoch)) {
            return false
        };

        // 2. Verify cryptographic signature
        if (!verify_signature(attestation)) {
            return false
        };

        // 3. Validate enclave is trusted
        if (!validate_enclave_measurement(attestation, registry)) {
            return false
        };

        // 4. Check TEE type is valid
        let tee_type = nautilus_types::tee_type(attestation);
        if (tee_type != nautilus_types::tee_type_sgx() && tee_type != nautilus_types::tee_type_tdx()) {
            return false
        };

        true
    }

    // ========== Assertion Functions (for entry points) ==========

    /// Assert timestamp is valid (throws error if not)
    public fun assert_valid_timestamp(
        attestation_timestamp: u64,
        current_epoch: u64,
    ) {
        assert!(
            validate_timestamp(attestation_timestamp, current_epoch),
            E_ATTESTATION_EXPIRED
        );
    }

    /// Assert signature is valid (throws error if not)
    public fun assert_valid_signature(attestation: &Attestation) {
        assert!(
            verify_signature(attestation),
            E_INVALID_SIGNATURE
        );
    }

    /// Assert enclave is trusted (throws error if not)
    public fun assert_trusted_enclave(
        attestation: &Attestation,
        registry: &EnclaveRegistry,
    ) {
        assert!(
            validate_enclave_measurement(attestation, registry),
            E_UNTRUSTED_ENCLAVE
        );
    }

    /// Assert full attestation is valid (throws error if not)
    public fun assert_valid_attestation(
        attestation: &Attestation,
        registry: &EnclaveRegistry,
        ctx: &TxContext,
    ) {
        assert!(
            validate_attestation(attestation, registry, ctx),
            E_INVALID_SIGNATURE // Generic error, specific one determined by validate_attestation
        );
    }

    // ========== Error Code Getters ==========

    public fun e_attestation_expired(): u64 { E_ATTESTATION_EXPIRED }
    public fun e_invalid_signature(): u64 { E_INVALID_SIGNATURE }
    public fun e_untrusted_enclave(): u64 { E_UNTRUSTED_ENCLAVE }
    public fun e_attestation_too_new(): u64 { E_ATTESTATION_TOO_NEW }
    public fun e_invalid_tee_type(): u64 { E_INVALID_TEE_TYPE }
}
