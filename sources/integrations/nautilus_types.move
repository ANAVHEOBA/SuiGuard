/// Nautilus TEE Attestation Data Structures
/// Defines types for TEE (SGX/TDX) attestation verification
module suiguard::nautilus_types {
    use std::option::{Self, Option};
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    /// TEE type identifiers
    const TEE_TYPE_SGX: u8 = 0;
    const TEE_TYPE_TDX: u8 = 1;

    /// Attestation status
    const STATUS_PENDING: u8 = 0;
    const STATUS_VERIFIED: u8 = 1;
    const STATUS_REJECTED: u8 = 2;

    /// TEE Attestation object
    /// Contains proof that code executed inside a Trusted Execution Environment
    public struct Attestation has key, store {
        id: UID,
        /// Type of TEE (SGX or TDX)
        tee_type: u8,
        /// Raw attestation quote/report from Nautilus enclave
        quote: vector<u8>,
        /// Enclave measurement (MRENCLAVE for SGX, MRTD for TDX)
        enclave_measurement: vector<u8>,
        /// Signer measurement (MRSIGNER for SGX)
        signer_measurement: vector<u8>,
        /// Cryptographic signature over the attestation
        signature: vector<u8>,
        /// Public key used for signature verification
        public_key: vector<u8>,
        /// Timestamp when attestation was created
        timestamp: u64,
        /// Nonce for replay attack prevention
        nonce: vector<u8>,
        /// Researcher who submitted this attestation
        researcher: address,
        /// Optional: ID of bug report this proves (can be empty initially)
        bug_report_id: Option<address>,
        /// Verification status
        status: u8,
        /// Result: true if exploit was confirmed by TEE
        exploit_confirmed: bool,
        /// When this attestation was verified on-chain
        verified_at: u64,
    }

    /// Trusted Enclave Registry Entry
    /// Whitelist of legitimate Nautilus enclave measurements
    public struct TrustedEnclave has store, copy, drop {
        /// Enclave measurement hash (MRENCLAVE/MRTD)
        measurement: vector<u8>,
        /// Human-readable description
        description: vector<u8>,
        /// When this enclave was whitelisted
        added_at: u64,
        /// Whether this enclave is currently trusted
        active: bool,
    }

    // ========== Constructor (package-only) ==========

    public(package) fun new_attestation(
        tee_type: u8,
        quote: vector<u8>,
        enclave_measurement: vector<u8>,
        signer_measurement: vector<u8>,
        signature: vector<u8>,
        public_key: vector<u8>,
        timestamp: u64,
        nonce: vector<u8>,
        researcher: address,
        bug_report_id: Option<address>,
        ctx: &mut TxContext,
    ): Attestation {
        Attestation {
            id: object::new(ctx),
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
            status: STATUS_PENDING,
            exploit_confirmed: false,
            verified_at: 0,
        }
    }

    public(package) fun new_trusted_enclave(
        measurement: vector<u8>,
        description: vector<u8>,
        added_at: u64,
    ): TrustedEnclave {
        TrustedEnclave {
            measurement,
            description,
            added_at,
            active: true,
        }
    }

    // ========== Getters ==========

    public fun id(attestation: &Attestation): &UID {
        &attestation.id
    }

    public fun tee_type(attestation: &Attestation): u8 {
        attestation.tee_type
    }

    public fun quote(attestation: &Attestation): &vector<u8> {
        &attestation.quote
    }

    public fun enclave_measurement(attestation: &Attestation): &vector<u8> {
        &attestation.enclave_measurement
    }

    public fun signer_measurement(attestation: &Attestation): &vector<u8> {
        &attestation.signer_measurement
    }

    public fun signature(attestation: &Attestation): &vector<u8> {
        &attestation.signature
    }

    public fun public_key(attestation: &Attestation): &vector<u8> {
        &attestation.public_key
    }

    public fun timestamp(attestation: &Attestation): u64 {
        attestation.timestamp
    }

    public fun nonce(attestation: &Attestation): &vector<u8> {
        &attestation.nonce
    }

    public fun researcher(attestation: &Attestation): address {
        attestation.researcher
    }

    public fun bug_report_id(attestation: &Attestation): &Option<address> {
        &attestation.bug_report_id
    }

    public fun status(attestation: &Attestation): u8 {
        attestation.status
    }

    public fun exploit_confirmed(attestation: &Attestation): bool {
        attestation.exploit_confirmed
    }

    public fun verified_at(attestation: &Attestation): u64 {
        attestation.verified_at
    }

    public fun is_verified(attestation: &Attestation): bool {
        attestation.status == STATUS_VERIFIED
    }

    public fun is_rejected(attestation: &Attestation): bool {
        attestation.status == STATUS_REJECTED
    }

    // ========== Trusted Enclave Getters ==========

    public fun enclave_measurement_hash(enclave: &TrustedEnclave): &vector<u8> {
        &enclave.measurement
    }

    public fun enclave_description(enclave: &TrustedEnclave): &vector<u8> {
        &enclave.description
    }

    public fun enclave_added_at(enclave: &TrustedEnclave): u64 {
        enclave.added_at
    }

    public fun enclave_is_active(enclave: &TrustedEnclave): bool {
        enclave.active
    }

    // ========== Mutable Setters (package-only) ==========

    public(package) fun set_status(attestation: &mut Attestation, status: u8) {
        attestation.status = status;
    }

    public(package) fun set_exploit_confirmed(attestation: &mut Attestation, confirmed: bool) {
        attestation.exploit_confirmed = confirmed;
    }

    public(package) fun set_verified_at(attestation: &mut Attestation, timestamp: u64) {
        attestation.verified_at = timestamp;
    }

    public(package) fun set_bug_report_id(attestation: &mut Attestation, report_id: address) {
        attestation.bug_report_id = option::some(report_id);
    }

    public(package) fun deactivate_enclave(enclave: &mut TrustedEnclave) {
        enclave.active = false;
    }

    public(package) fun activate_enclave(enclave: &mut TrustedEnclave) {
        enclave.active = true;
    }

    // ========== Constants ==========

    public fun tee_type_sgx(): u8 { TEE_TYPE_SGX }
    public fun tee_type_tdx(): u8 { TEE_TYPE_TDX }

    public fun status_pending(): u8 { STATUS_PENDING }
    public fun status_verified(): u8 { STATUS_VERIFIED }
    public fun status_rejected(): u8 { STATUS_REJECTED }
}
