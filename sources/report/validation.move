/// Input validation for bug report operations
module suiguard::report_validation {
    use std::vector;
    use suiguard::constants;

    // ========== Validation Constants ==========

    /// Minimum submission fee: 10 SUI (anti-spam measure)
    const MIN_SUBMISSION_FEE: u64 = 10_000_000_000;

    /// Maximum severity level (0-4: Critical, High, Medium, Low, Informational)
    const MAX_SEVERITY: u8 = 4;

    /// Maximum category value (0-7: see report_types for categories)
    const MAX_CATEGORY: u8 = 7;

    // ========== Error Codes (2000-2099) ==========

    /// Invalid severity level
    const E_INVALID_SEVERITY: u64 = 2010;

    /// Invalid vulnerability category
    const E_INVALID_CATEGORY: u64 = 2011;

    /// Submission fee too low
    const E_FEE_TOO_LOW: u64 = 2012;

    /// Walrus blob ID is empty
    const E_EMPTY_BLOB_ID: u64 = 2013;

    /// Vulnerability hash is empty
    const E_EMPTY_VULNERABILITY_HASH: u64 = 2014;

    /// Report cannot be withdrawn in current state
    const E_CANNOT_WITHDRAW: u64 = 2015;

    /// Caller is not the researcher who submitted the report
    const E_NOT_RESEARCHER: u64 = 2016;

    /// Report is already marked as duplicate
    const E_ALREADY_DUPLICATE: u64 = 2017;

    /// Invalid status transition
    const E_INVALID_STATUS_TRANSITION: u64 = 2018;

    // ========== Validation Functions ==========

    /// Validate severity level is within valid range (0-4)
    public fun validate_severity(severity: u8) {
        assert!(severity <= MAX_SEVERITY, E_INVALID_SEVERITY);
    }

    /// Validate category is within valid range (0-7)
    public fun validate_category(category: u8) {
        assert!(category <= MAX_CATEGORY, E_INVALID_CATEGORY);
    }

    /// Validate submission fee meets minimum requirement
    public fun validate_submission_fee(amount: u64) {
        assert!(amount >= MIN_SUBMISSION_FEE, E_FEE_TOO_LOW);
    }

    /// Validate Walrus blob ID is not empty
    public fun validate_walrus_blob_id(blob_id: &vector<u8>) {
        assert!(!vector::is_empty(blob_id), E_EMPTY_BLOB_ID);
    }

    /// Validate vulnerability hash is not empty
    public fun validate_vulnerability_hash(hash: &vector<u8>) {
        assert!(!vector::is_empty(hash), E_EMPTY_VULNERABILITY_HASH);
    }

    /// Validate all required fields for bug report submission
    public fun validate_bug_report_submission(
        severity: u8,
        category: u8,
        walrus_blob_id: &vector<u8>,
        vulnerability_hash: &vector<u8>,
        submission_fee: u64,
    ) {
        validate_severity(severity);
        validate_category(category);
        validate_walrus_blob_id(walrus_blob_id);
        validate_vulnerability_hash(vulnerability_hash);
        validate_submission_fee(submission_fee);
    }

    /// Validate researcher authorization
    public fun validate_researcher(expected: address, actual: address) {
        assert!(expected == actual, E_NOT_RESEARCHER);
    }

    /// Validate report can be withdrawn (only in SUBMITTED status)
    public fun validate_can_withdraw(status: u8) {
        // STATUS_SUBMITTED = 0 (from report_types)
        assert!(status == 0, E_CANNOT_WITHDRAW);
    }

    /// Validate report is not already a duplicate
    public fun validate_not_duplicate(status: u8) {
        // STATUS_DUPLICATE = 4 (from report_types)
        assert!(status != 4, E_ALREADY_DUPLICATE);
    }

    /// Validate status transition is allowed
    /// Enforces state machine rules for report lifecycle
    public fun validate_status_transition(current_status: u8, new_status: u8) {
        // STATUS_SUBMITTED = 0
        // STATUS_UNDER_REVIEW = 1
        // STATUS_ACCEPTED = 2
        // STATUS_REJECTED = 3
        // STATUS_DUPLICATE = 4
        // STATUS_WITHDRAWN = 5
        // STATUS_PAID = 6

        // Allow any transition from SUBMITTED
        if (current_status == 0) {
            return
        };

        // From UNDER_REVIEW, can only go to ACCEPTED, REJECTED, or DUPLICATE
        if (current_status == 1) {
            assert!(
                new_status == 2 || new_status == 3 || new_status == 4,
                E_INVALID_STATUS_TRANSITION
            );
            return
        };

        // From ACCEPTED, can only go to PAID
        if (current_status == 2) {
            assert!(new_status == 6, E_INVALID_STATUS_TRANSITION);
            return
        };

        // REJECTED, DUPLICATE, WITHDRAWN, and PAID are terminal states
        assert!(false, E_INVALID_STATUS_TRANSITION);
    }

    // ========== Getter Functions for Error Codes ==========

    public fun e_invalid_severity(): u64 { E_INVALID_SEVERITY }
    public fun e_invalid_category(): u64 { E_INVALID_CATEGORY }
    public fun e_fee_too_low(): u64 { E_FEE_TOO_LOW }
    public fun e_empty_blob_id(): u64 { E_EMPTY_BLOB_ID }
    public fun e_empty_vulnerability_hash(): u64 { E_EMPTY_VULNERABILITY_HASH }
    public fun e_cannot_withdraw(): u64 { E_CANNOT_WITHDRAW }
    public fun e_not_researcher(): u64 { E_NOT_RESEARCHER }
    public fun e_already_duplicate(): u64 { E_ALREADY_DUPLICATE }
    public fun e_invalid_status_transition(): u64 { E_INVALID_STATUS_TRANSITION }

    // ========== Getter Functions for Constants ==========

    public fun min_submission_fee(): u64 { MIN_SUBMISSION_FEE }
    public fun max_severity(): u8 { MAX_SEVERITY }
    public fun max_category(): u8 { MAX_CATEGORY }
}
