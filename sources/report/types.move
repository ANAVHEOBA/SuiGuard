/// Bug Report Data Models - Refactored with split structs
/// Reduces complexity by splitting into multiple smaller objects
module suiguard::report_types {
    use std::option::{Self, Option};
    use sui::object::{Self, UID, ID};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::tx_context::TxContext;
    use sui::dynamic_field as df;

    /// Vulnerability categories
    const CATEGORY_REENTRANCY: u8 = 0;
    const CATEGORY_OVERFLOW: u8 = 1;
    const CATEGORY_LOGIC_ERROR: u8 = 2;
    const CATEGORY_ACCESS_CONTROL: u8 = 3;
    const CATEGORY_PRICE_MANIPULATION: u8 = 4;
    const CATEGORY_DENIAL_OF_SERVICE: u8 = 5;
    const CATEGORY_FRONT_RUNNING: u8 = 6;
    const CATEGORY_OTHER: u8 = 7;

    /// Report status
    const STATUS_SUBMITTED: u8 = 0;
    const STATUS_UNDER_REVIEW: u8 = 1;
    const STATUS_ACCEPTED: u8 = 2;
    const STATUS_REJECTED: u8 = 3;
    const STATUS_DUPLICATE: u8 = 4;
    const STATUS_WITHDRAWN: u8 = 5;
    const STATUS_PAID: u8 = 6;

    /// Dynamic field keys
    public struct ProjectResponseKey has copy, drop, store {}
    public struct FixDataKey has copy, drop, store {}
    public struct PayoutDataKey has copy, drop, store {}
    public struct DisclosureDataKey has copy, drop, store {}

    /// Core Bug Report object (reduced to essential fields)
    public struct BugReport has key, store {
        id: UID,
        program_id: ID,
        researcher: address,
        severity: u8,
        category: u8,
        walrus_blob_id: vector<u8>,
        seal_policy_id: Option<vector<u8>>,
        affected_targets: vector<vector<u8>>,
        vulnerability_hash: vector<u8>,
        submission_fee: Balance<SUI>,
        status: u8,
        submitted_at: u64,
        updated_at: u64,
        duplicate_of: Option<ID>,
        attestation_id: Option<ID>,
    }

    /// Project response data (stored as dynamic field)
    public struct ProjectResponse has store, drop {
        acknowledged_at: Option<u64>,
        clarification_requested: bool,
        clarification_message_blob: Option<vector<u8>>,
        severity_disputed: bool,
        dispute_triage_vote_id: Option<ID>,
    }

    /// Fix verification data (stored as dynamic field)
    public struct FixData has store, drop {
        fix_submitted: bool,
        fix_commit_hash: Option<vector<u8>>,
        fix_package_id: Option<address>,
        fix_submitted_at: Option<u64>,
        fix_verified: bool,
        fix_verified_at: Option<u64>,
        fix_verification_attestation: Option<ID>,
    }

    /// Payout data (stored as dynamic field)
    public struct PayoutData has store, drop {
        payout_amount: u64,
        payout_executed: bool,
        payout_executed_at: Option<u64>,
        has_split_proposal: bool,
        split_proposal_id: Option<ID>,
    }

    /// Disclosure data (stored as dynamic field)
    public struct DisclosureData has store, drop {
        disclosure_deadline: u64,
        publicly_disclosed: bool,
        disclosed_at: Option<u64>,
        early_disclosure_requested: bool,
        early_disclosure_requested_at: Option<u64>,
        early_disclosure_approved: bool,
        public_seal_policy: Option<vector<u8>>,
    }

    /// Vulnerability signature for duplicate detection
    public struct VulnerabilitySignature has store, copy, drop {
        program_id: ID,
        vulnerability_hash: vector<u8>,
    }

    // ========== Constructor (package-only) ==========

    public(package) fun new(
        program_id: ID,
        researcher: address,
        severity: u8,
        category: u8,
        walrus_blob_id: vector<u8>,
        seal_policy_id: Option<vector<u8>>,
        affected_targets: vector<vector<u8>>,
        vulnerability_hash: vector<u8>,
        submission_fee: Balance<SUI>,
        submitted_at: u64,
        ctx: &mut TxContext,
    ): BugReport {
        let mut report = BugReport {
            id: object::new(ctx),
            program_id,
            researcher,
            severity,
            category,
            walrus_blob_id,
            seal_policy_id,
            affected_targets,
            vulnerability_hash,
            submission_fee,
            status: STATUS_SUBMITTED,
            submitted_at,
            updated_at: submitted_at,
            duplicate_of: option::none(),
            attestation_id: option::none(),
        };

        // Initialize dynamic fields
        df::add(&mut report.id, ProjectResponseKey {}, ProjectResponse {
            acknowledged_at: option::none(),
            clarification_requested: false,
            clarification_message_blob: option::none(),
            severity_disputed: false,
            dispute_triage_vote_id: option::none(),
        });

        df::add(&mut report.id, FixDataKey {}, FixData {
            fix_submitted: false,
            fix_commit_hash: option::none(),
            fix_package_id: option::none(),
            fix_submitted_at: option::none(),
            fix_verified: false,
            fix_verified_at: option::none(),
            fix_verification_attestation: option::none(),
        });

        df::add(&mut report.id, PayoutDataKey {}, PayoutData {
            payout_amount: 0,
            payout_executed: false,
            payout_executed_at: option::none(),
            has_split_proposal: false,
            split_proposal_id: option::none(),
        });

        df::add(&mut report.id, DisclosureDataKey {}, DisclosureData {
            disclosure_deadline: submitted_at + 90,
            publicly_disclosed: false,
            disclosed_at: option::none(),
            early_disclosure_requested: false,
            early_disclosure_requested_at: option::none(),
            early_disclosure_approved: false,
            public_seal_policy: option::none(),
        });

        report
    }

    public(package) fun new_vulnerability_signature(
        program_id: ID,
        vulnerability_hash: vector<u8>,
    ): VulnerabilitySignature {
        VulnerabilitySignature {
            program_id,
            vulnerability_hash,
        }
    }

    // ========== Core Getters ==========

    public fun id(report: &BugReport): &UID {
        &report.id
    }

    public fun program_id(report: &BugReport): ID {
        report.program_id
    }

    public fun researcher(report: &BugReport): address {
        report.researcher
    }

    public fun severity(report: &BugReport): u8 {
        report.severity
    }

    public fun category(report: &BugReport): u8 {
        report.category
    }

    public fun walrus_blob_id(report: &BugReport): &vector<u8> {
        &report.walrus_blob_id
    }

    public fun seal_policy_id(report: &BugReport): &Option<vector<u8>> {
        &report.seal_policy_id
    }

    public fun affected_targets(report: &BugReport): &vector<vector<u8>> {
        &report.affected_targets
    }

    public fun vulnerability_hash(report: &BugReport): &vector<u8> {
        &report.vulnerability_hash
    }

    public fun submission_fee_value(report: &BugReport): u64 {
        balance::value(&report.submission_fee)
    }

    public fun status(report: &BugReport): u8 {
        report.status
    }

    public fun submitted_at(report: &BugReport): u64 {
        report.submitted_at
    }

    public fun updated_at(report: &BugReport): u64 {
        report.updated_at
    }

    public fun duplicate_of(report: &BugReport): &Option<ID> {
        &report.duplicate_of
    }

    public fun attestation_id(report: &BugReport): &Option<ID> {
        &report.attestation_id
    }

    public fun is_submitted(report: &BugReport): bool {
        report.status == STATUS_SUBMITTED
    }

    public fun is_under_review(report: &BugReport): bool {
        report.status == STATUS_UNDER_REVIEW
    }

    public fun is_accepted(report: &BugReport): bool {
        report.status == STATUS_ACCEPTED
    }

    public fun is_rejected(report: &BugReport): bool {
        report.status == STATUS_REJECTED
    }

    public fun is_duplicate(report: &BugReport): bool {
        report.status == STATUS_DUPLICATE
    }

    public fun is_withdrawn(report: &BugReport): bool {
        report.status == STATUS_WITHDRAWN
    }

    public fun is_paid(report: &BugReport): bool {
        report.status == STATUS_PAID
    }

    // ========== VulnerabilitySignature Getters ==========

    public fun sig_program_id(sig: &VulnerabilitySignature): ID {
        sig.program_id
    }

    public fun sig_hash(sig: &VulnerabilitySignature): &vector<u8> {
        &sig.vulnerability_hash
    }

    // ========== Core Setters (package-only) ==========

    public(package) fun set_status(report: &mut BugReport, status: u8) {
        report.status = status;
    }

    public(package) fun set_severity(report: &mut BugReport, severity: u8) {
        report.severity = severity;
    }

    public(package) fun set_updated_at(report: &mut BugReport, timestamp: u64) {
        report.updated_at = timestamp;
    }

    public(package) fun set_duplicate_of(report: &mut BugReport, original_id: ID) {
        report.duplicate_of = option::some(original_id);
    }

    public(package) fun set_attestation_id(report: &mut BugReport, attestation_id: ID) {
        report.attestation_id = option::some(attestation_id);
    }

    // ========== Project Response Getters/Setters ==========

    public fun acknowledged_at(report: &BugReport): Option<u64> {
        df::borrow<ProjectResponseKey, ProjectResponse>(&report.id, ProjectResponseKey {}).acknowledged_at
    }

    public fun clarification_requested(report: &BugReport): bool {
        df::borrow<ProjectResponseKey, ProjectResponse>(&report.id, ProjectResponseKey {}).clarification_requested
    }

    public fun clarification_message_blob(report: &BugReport): Option<vector<u8>> {
        df::borrow<ProjectResponseKey, ProjectResponse>(&report.id, ProjectResponseKey {}).clarification_message_blob
    }

    public fun severity_disputed(report: &BugReport): bool {
        df::borrow<ProjectResponseKey, ProjectResponse>(&report.id, ProjectResponseKey {}).severity_disputed
    }

    public fun dispute_triage_vote_id(report: &BugReport): Option<ID> {
        df::borrow<ProjectResponseKey, ProjectResponse>(&report.id, ProjectResponseKey {}).dispute_triage_vote_id
    }

    public(package) fun acknowledge_report_internal(report: &mut BugReport, timestamp: u64) {
        let response = df::borrow_mut<ProjectResponseKey, ProjectResponse>(&mut report.id, ProjectResponseKey {});
        response.acknowledged_at = option::some(timestamp);
        report.updated_at = timestamp;
    }

    public(package) fun request_clarification_internal(
        report: &mut BugReport,
        message_blob: vector<u8>,
        timestamp: u64,
    ) {
        let response = df::borrow_mut<ProjectResponseKey, ProjectResponse>(&mut report.id, ProjectResponseKey {});
        response.clarification_requested = true;
        response.clarification_message_blob = option::some(message_blob);
        report.updated_at = timestamp;
    }

    public(package) fun dispute_severity_internal(
        report: &mut BugReport,
        triage_vote_id: ID,
        timestamp: u64,
    ) {
        let response = df::borrow_mut<ProjectResponseKey, ProjectResponse>(&mut report.id, ProjectResponseKey {});
        response.severity_disputed = true;
        response.dispute_triage_vote_id = option::some(triage_vote_id);
        report.updated_at = timestamp;
    }

    // ========== Fix Data Getters/Setters ==========

    public fun fix_submitted(report: &BugReport): bool {
        df::borrow<FixDataKey, FixData>(&report.id, FixDataKey {}).fix_submitted
    }

    public fun fix_commit_hash(report: &BugReport): Option<vector<u8>> {
        df::borrow<FixDataKey, FixData>(&report.id, FixDataKey {}).fix_commit_hash
    }

    public fun fix_package_id(report: &BugReport): Option<address> {
        df::borrow<FixDataKey, FixData>(&report.id, FixDataKey {}).fix_package_id
    }

    public fun fix_submitted_at(report: &BugReport): Option<u64> {
        df::borrow<FixDataKey, FixData>(&report.id, FixDataKey {}).fix_submitted_at
    }

    public fun fix_verified(report: &BugReport): bool {
        df::borrow<FixDataKey, FixData>(&report.id, FixDataKey {}).fix_verified
    }

    public fun fix_verified_at(report: &BugReport): Option<u64> {
        df::borrow<FixDataKey, FixData>(&report.id, FixDataKey {}).fix_verified_at
    }

    public fun fix_verification_attestation(report: &BugReport): Option<ID> {
        df::borrow<FixDataKey, FixData>(&report.id, FixDataKey {}).fix_verification_attestation
    }

    public(package) fun submit_fix_internal(
        report: &mut BugReport,
        commit_hash: Option<vector<u8>>,
        package_id: Option<address>,
        timestamp: u64,
    ) {
        let fix_data = df::borrow_mut<FixDataKey, FixData>(&mut report.id, FixDataKey {});
        fix_data.fix_submitted = true;
        fix_data.fix_commit_hash = commit_hash;
        fix_data.fix_package_id = package_id;
        fix_data.fix_submitted_at = option::some(timestamp);
        report.updated_at = timestamp;
    }

    public(package) fun verify_fix_internal(
        report: &mut BugReport,
        attestation_id: Option<ID>,
        timestamp: u64,
    ) {
        let fix_data = df::borrow_mut<FixDataKey, FixData>(&mut report.id, FixDataKey {});
        fix_data.fix_verified = true;
        fix_data.fix_verified_at = option::some(timestamp);
        fix_data.fix_verification_attestation = attestation_id;
        report.updated_at = timestamp;
    }

    // ========== Payout Data Getters/Setters ==========

    public fun payout_amount(report: &BugReport): u64 {
        df::borrow<PayoutDataKey, PayoutData>(&report.id, PayoutDataKey {}).payout_amount
    }

    public fun payout_executed(report: &BugReport): bool {
        df::borrow<PayoutDataKey, PayoutData>(&report.id, PayoutDataKey {}).payout_executed
    }

    public fun payout_executed_at(report: &BugReport): Option<u64> {
        df::borrow<PayoutDataKey, PayoutData>(&report.id, PayoutDataKey {}).payout_executed_at
    }

    public fun has_split_proposal(report: &BugReport): bool {
        df::borrow<PayoutDataKey, PayoutData>(&report.id, PayoutDataKey {}).has_split_proposal
    }

    public fun split_proposal_id(report: &BugReport): Option<ID> {
        df::borrow<PayoutDataKey, PayoutData>(&report.id, PayoutDataKey {}).split_proposal_id
    }

    public(package) fun set_payout_amount_internal(report: &mut BugReport, amount: u64) {
        let payout_data = df::borrow_mut<PayoutDataKey, PayoutData>(&mut report.id, PayoutDataKey {});
        payout_data.payout_amount = amount;
    }

    public(package) fun execute_payout_internal(report: &mut BugReport, timestamp: u64) {
        let payout_data = df::borrow_mut<PayoutDataKey, PayoutData>(&mut report.id, PayoutDataKey {});
        payout_data.payout_executed = true;
        payout_data.payout_executed_at = option::some(timestamp);
        report.updated_at = timestamp;
    }

    public(package) fun set_split_proposal_internal(report: &mut BugReport, proposal_id: ID) {
        let payout_data = df::borrow_mut<PayoutDataKey, PayoutData>(&mut report.id, PayoutDataKey {});
        payout_data.has_split_proposal = true;
        payout_data.split_proposal_id = option::some(proposal_id);
    }

    public(package) fun clear_split_proposal_internal(report: &mut BugReport) {
        let payout_data = df::borrow_mut<PayoutDataKey, PayoutData>(&mut report.id, PayoutDataKey {});
        payout_data.has_split_proposal = false;
        payout_data.split_proposal_id = option::none();
    }

    // ========== Disclosure Data Getters/Setters ==========

    public fun disclosure_deadline(report: &BugReport): u64 {
        df::borrow<DisclosureDataKey, DisclosureData>(&report.id, DisclosureDataKey {}).disclosure_deadline
    }

    public fun publicly_disclosed(report: &BugReport): bool {
        df::borrow<DisclosureDataKey, DisclosureData>(&report.id, DisclosureDataKey {}).publicly_disclosed
    }

    public fun disclosed_at(report: &BugReport): Option<u64> {
        df::borrow<DisclosureDataKey, DisclosureData>(&report.id, DisclosureDataKey {}).disclosed_at
    }

    public fun early_disclosure_requested(report: &BugReport): bool {
        df::borrow<DisclosureDataKey, DisclosureData>(&report.id, DisclosureDataKey {}).early_disclosure_requested
    }

    public fun early_disclosure_requested_at(report: &BugReport): Option<u64> {
        df::borrow<DisclosureDataKey, DisclosureData>(&report.id, DisclosureDataKey {}).early_disclosure_requested_at
    }

    public fun early_disclosure_approved(report: &BugReport): bool {
        df::borrow<DisclosureDataKey, DisclosureData>(&report.id, DisclosureDataKey {}).early_disclosure_approved
    }

    public fun public_seal_policy(report: &BugReport): Option<vector<u8>> {
        df::borrow<DisclosureDataKey, DisclosureData>(&report.id, DisclosureDataKey {}).public_seal_policy
    }

    public(package) fun trigger_disclosure_internal(
        report: &mut BugReport,
        public_seal_policy: vector<u8>,
        timestamp: u64,
    ) {
        let disclosure = df::borrow_mut<DisclosureDataKey, DisclosureData>(&mut report.id, DisclosureDataKey {});
        disclosure.publicly_disclosed = true;
        disclosure.disclosed_at = option::some(timestamp);
        disclosure.public_seal_policy = option::some(public_seal_policy);
        report.updated_at = timestamp;
    }

    public(package) fun request_early_disclosure_internal(report: &mut BugReport, timestamp: u64) {
        let disclosure = df::borrow_mut<DisclosureDataKey, DisclosureData>(&mut report.id, DisclosureDataKey {});
        disclosure.early_disclosure_requested = true;
        disclosure.early_disclosure_requested_at = option::some(timestamp);
        report.updated_at = timestamp;
    }

    public(package) fun approve_early_disclosure_internal(report: &mut BugReport) {
        let disclosure = df::borrow_mut<DisclosureDataKey, DisclosureData>(&mut report.id, DisclosureDataKey {});
        disclosure.early_disclosure_approved = true;
    }

    public(package) fun withdraw_early_disclosure_request_internal(report: &mut BugReport) {
        let disclosure = df::borrow_mut<DisclosureDataKey, DisclosureData>(&mut report.id, DisclosureDataKey {});
        disclosure.early_disclosure_requested = false;
        disclosure.early_disclosure_requested_at = option::none();
    }

    // ========== Balance Management (package-only) ==========

    public(package) fun extract_submission_fee(report: &mut BugReport): Balance<SUI> {
        balance::withdraw_all(&mut report.submission_fee)
    }

    // Alias for backward compatibility
    public(package) fun withdraw_fee(report: &mut BugReport): Balance<SUI> {
        extract_submission_fee(report)
    }

    public(package) fun add_to_submission_fee(report: &mut BugReport, amount: Balance<SUI>) {
        balance::join(&mut report.submission_fee, amount);
    }

    // ========== Status Constants (public for other modules) ==========

    public fun status_submitted(): u8 { STATUS_SUBMITTED }
    public fun status_under_review(): u8 { STATUS_UNDER_REVIEW }
    public fun status_accepted(): u8 { STATUS_ACCEPTED }
    public fun status_rejected(): u8 { STATUS_REJECTED }
    public fun status_duplicate(): u8 { STATUS_DUPLICATE }
    public fun status_withdrawn(): u8 { STATUS_WITHDRAWN }
    public fun status_paid(): u8 { STATUS_PAID }

    // ========== Additional Helper Functions ==========

    // Backward compatibility aliases
    public(package) fun set_payout_amount(report: &mut BugReport, amount: u64) {
        set_payout_amount_internal(report, amount);
    }

    public(package) fun set_split_proposal(report: &mut BugReport, proposal_id: ID) {
        set_split_proposal_internal(report, proposal_id);
    }

    public(package) fun clear_split_proposal(report: &mut BugReport) {
        clear_split_proposal_internal(report);
    }

    public(package) fun execute_payout(report: &mut BugReport, timestamp: u64) {
        execute_payout_internal(report, timestamp);
    }

    // Destroy empty report (for cleanup)
    public(package) fun destroy_empty(report: BugReport) {
        let BugReport {
            mut id,
            program_id: _,
            researcher: _,
            severity: _,
            category: _,
            walrus_blob_id: _,
            seal_policy_id: _,
            affected_targets: _,
            vulnerability_hash: _,
            submission_fee,
            status: _,
            submitted_at: _,
            updated_at: _,
            duplicate_of: _,
            attestation_id: _,
        } = report;

        // Destroy dynamic fields
        let _proj_response: ProjectResponse = df::remove(&mut id, ProjectResponseKey {});
        let _fix_data: FixData = df::remove(&mut id, FixDataKey {});
        let _payout_data: PayoutData = df::remove(&mut id, PayoutDataKey {});
        let _disclosure: DisclosureData = df::remove(&mut id, DisclosureDataKey {});

        // Destroy submission fee balance
        balance::destroy_zero(submission_fee);

        // Destroy UID
        object::delete(id);
    }
}
