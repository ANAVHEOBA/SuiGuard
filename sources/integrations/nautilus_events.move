/// Nautilus TEE Attestation Events
/// Events emitted during attestation lifecycle
module suiguard::nautilus_events {
    use sui::object::ID;
    use sui::event;

    /// Emitted when a new attestation is submitted
    public struct AttestationSubmitted has copy, drop {
        attestation_id: ID,
        researcher: address,
        tee_type: u8,
        enclave_measurement: vector<u8>,
        timestamp: u64,
        bug_report_id: Option<address>,
    }

    /// Emitted when an attestation is verified
    public struct AttestationVerified has copy, drop {
        attestation_id: ID,
        researcher: address,
        exploit_confirmed: bool,
        verified_at: u64,
    }

    /// Emitted when an attestation is rejected
    public struct AttestationRejected has copy, drop {
        attestation_id: ID,
        researcher: address,
        reason: vector<u8>,
    }

    /// Emitted when a trusted enclave is added
    public struct EnclaveAdded has copy, drop {
        enclave_measurement: vector<u8>,
        description: vector<u8>,
        added_at: u64,
    }

    /// Emitted when a trusted enclave is revoked
    public struct EnclaveRevoked has copy, drop {
        enclave_measurement: vector<u8>,
        revoked_at: u64,
    }

    /// Emitted when a revoked enclave is restored
    public struct EnclaveRestored has copy, drop {
        enclave_measurement: vector<u8>,
        restored_at: u64,
    }

    // ========== Event Emission Functions ==========

    public(package) fun emit_attestation_submitted(
        attestation_id: ID,
        researcher: address,
        tee_type: u8,
        enclave_measurement: vector<u8>,
        timestamp: u64,
        bug_report_id: Option<address>,
    ) {
        event::emit(AttestationSubmitted {
            attestation_id,
            researcher,
            tee_type,
            enclave_measurement,
            timestamp,
            bug_report_id,
        });
    }

    public(package) fun emit_attestation_verified(
        attestation_id: ID,
        researcher: address,
        exploit_confirmed: bool,
        verified_at: u64,
    ) {
        event::emit(AttestationVerified {
            attestation_id,
            researcher,
            exploit_confirmed,
            verified_at,
        });
    }

    public(package) fun emit_attestation_rejected(
        attestation_id: ID,
        researcher: address,
        reason: vector<u8>,
    ) {
        event::emit(AttestationRejected {
            attestation_id,
            researcher,
            reason,
        });
    }

    public(package) fun emit_enclave_added(
        enclave_measurement: vector<u8>,
        description: vector<u8>,
        added_at: u64,
    ) {
        event::emit(EnclaveAdded {
            enclave_measurement,
            description,
            added_at,
        });
    }

    public(package) fun emit_enclave_revoked(
        enclave_measurement: vector<u8>,
        revoked_at: u64,
    ) {
        event::emit(EnclaveRevoked {
            enclave_measurement,
            revoked_at,
        });
    }

    public(package) fun emit_enclave_restored(
        enclave_measurement: vector<u8>,
        restored_at: u64,
    ) {
        event::emit(EnclaveRestored {
            enclave_measurement,
            restored_at,
        });
    }
}
