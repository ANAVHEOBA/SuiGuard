/// Public API for bug report submission and management
/// These are the entry functions that external users (researchers) call
module suiguard::report_api {
    use std::option::{Self, Option};
    use sui::transfer;
    use sui::coin::Coin;
    use sui::sui::SUI;
    use sui::object::{Self, ID};
    use sui::tx_context::{Self, TxContext};
    use suiguard::report_types::{Self, BugReport};
    use suiguard::report_crud;
    use suiguard::report_validation;
    use suiguard::duplicate_registry::{Self, DuplicateRegistry};
    use suiguard::bounty_types::BountyProgram;
    use suiguard::constants;

    // ========== Public Entry Functions ==========

    /// Submit a new bug report to a bounty program
    ///
    /// # Arguments
    /// * `program` - Reference to the bounty program (to verify it's active)
    /// * `registry` - Shared duplicate registry for detection
    /// * `severity` - Vulnerability severity (0-4: Critical, High, Medium, Low, Informational)
    /// * `category` - Vulnerability category (0-7: see report_types for list)
    /// * `walrus_blob_id` - Walrus blob ID containing encrypted report details
    /// * `seal_policy_id` - Optional Seal policy ID for time-locked disclosure (90 days default)
    /// * `affected_targets` - List of affected contract addresses/module names
    /// * `vulnerability_hash` - Hash of vulnerability signature for duplicate detection
    /// * `submission_fee` - Anti-spam fee (minimum 10 SUI, refunded if valid)
    ///
    /// # Behavior
    /// - Creates a BugReport object and transfers it to the researcher
    /// - The researcher owns the report until it's reviewed
    /// - Checks for duplicates and aborts if vulnerability already reported
    ///
    /// # Panics
    /// - If program is not active or has expired
    /// - If duplicate vulnerability is detected
    /// - If validation fails (invalid severity, category, fee, etc.)
    public entry fun submit_bug_report(
        program: &BountyProgram,
        registry: &DuplicateRegistry,
        severity: u8,
        category: u8,
        walrus_blob_id: vector<u8>,
        seal_policy_id_bytes: vector<u8>, // Empty vector means None
        affected_targets: vector<vector<u8>>,
        vulnerability_hash: vector<u8>,
        submission_fee: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        use suiguard::bounty_types;
        use suiguard::bounty_crud;
        use suiguard::walrus;
        use suiguard::seal;

        // Validate program is active and accepting reports
        let current_epoch = tx_context::epoch(ctx);
        assert!(
            bounty_crud::can_accept_reports(program, current_epoch),
            constants::e_program_not_active()
        );

        // Check for duplicate vulnerability
        let duplicate_check = duplicate_registry::check_duplicate(registry, &vulnerability_hash);
        assert!(
            option::is_none(&duplicate_check),
            constants::e_duplicate_report()
        );

        // Validate Walrus blob ID format
        walrus::assert_valid_blob_id(&walrus_blob_id);

        // Validate Seal policy ID if provided
        if (!std::vector::is_empty(&seal_policy_id_bytes)) {
            seal::assert_valid_policy_id(&seal_policy_id_bytes);
        };

        // Convert seal_policy_id to Option
        let seal_policy_id = if (std::vector::is_empty(&seal_policy_id_bytes)) {
            option::none()
        } else {
            option::some(seal_policy_id_bytes)
        };

        // Create the report
        let program_id = object::uid_to_inner(bounty_types::id(program));
        let report = report_crud::create(
            program_id,
            severity,
            category,
            walrus_blob_id,
            seal_policy_id,
            affected_targets,
            vulnerability_hash,
            submission_fee,
            ctx,
        );

        // Transfer ownership to researcher
        let researcher = tx_context::sender(ctx);
        transfer::public_transfer(report, researcher);
    }

    /// Withdraw a bug report before it has been reviewed
    /// Allows researcher to retract their submission and get their fee back
    ///
    /// # Arguments
    /// * `report` - The bug report to withdraw (must be owned by caller)
    /// * `registry` - Duplicate registry to clean up signature
    ///
    /// # Behavior
    /// - Validates caller is the researcher who submitted the report
    /// - Validates report is still in SUBMITTED status
    /// - Returns the submission fee to the researcher
    /// - Destroys the report object
    ///
    /// # Panics
    /// - If caller is not the researcher
    /// - If report is not in SUBMITTED status (already under review)
    public entry fun withdraw_report(
        report: BugReport,
        registry: &mut DuplicateRegistry,
        ctx: &mut TxContext,
    ) {
        // Withdraw and get fee back
        let fee = report_crud::withdraw(report, registry, ctx);

        // Return fee to researcher
        let researcher = tx_context::sender(ctx);
        transfer::public_transfer(fee, researcher);
    }

    /// Mark a report as duplicate of another report
    /// This is an admin/triage function called after review
    ///
    /// # Arguments
    /// * `report` - The report to mark as duplicate
    /// * `original_report_id` - ID of the original report
    /// * `registry` - Duplicate registry to update statistics
    ///
    /// # Behavior
    /// - Marks the report as DUPLICATE status
    /// - Links to the original report
    /// - Updates duplicate statistics
    /// - Typically called by triage committee or program owner
    ///
    /// # Panics
    /// - If report is already marked as duplicate
    /// - If status transition is invalid
    public entry fun mark_as_duplicate(
        report: &mut BugReport,
        original_report_id: ID,
        registry: &mut DuplicateRegistry,
        ctx: &TxContext,
    ) {
        report_crud::mark_duplicate(report, original_report_id, registry, ctx);
    }

    /// Link a TEE attestation to a bug report
    /// Proves the report was generated in a secure enclave (Nautilus)
    ///
    /// # Arguments
    /// * `report` - The report to link attestation to (must be owned by caller)
    /// * `attestation_id` - ID of the Nautilus attestation object
    ///
    /// # Behavior
    /// - Associates the attestation with the report
    /// - Provides additional credibility for the vulnerability claim
    /// - Can be done after initial submission
    ///
    /// # Panics
    /// - If caller is not the researcher who submitted the report
    public entry fun link_attestation(
        report: &mut BugReport,
        attestation_id: ID,
        ctx: &TxContext,
    ) {
        report_crud::link_attestation(report, attestation_id, ctx);
    }

    // ========== View Functions (No Gas Cost) ==========

    /// Check if a vulnerability signature is a duplicate
    /// Returns the original report ID if duplicate, None if unique
    ///
    /// # Arguments
    /// * `registry` - The duplicate registry
    /// * `vulnerability_hash` - Hash to check
    ///
    /// # Returns
    /// Option<ID> - Some(original_id) if duplicate, None if unique
    public fun check_duplicate(
        registry: &DuplicateRegistry,
        vulnerability_hash: vector<u8>,
    ): Option<ID> {
        duplicate_registry::check_duplicate(registry, &vulnerability_hash)
    }

    /// Check if a report can be withdrawn
    public fun can_withdraw(report: &BugReport): bool {
        report_crud::can_withdraw(report)
    }

    /// Check if a report is in a terminal state
    public fun is_terminal(report: &BugReport): bool {
        report_crud::is_terminal_state(report)
    }

    /// Get the original report ID if this is a duplicate
    public fun get_original_if_duplicate(report: &BugReport): Option<ID> {
        report_crud::get_duplicate_original(report)
    }

    /// Get report basic information
    public fun get_report_info(report: &BugReport): (ID, address, u8, u8, u8) {
        (
            object::uid_to_inner(report_types::id(report)),
            report_types::researcher(report),
            report_types::severity(report),
            report_types::category(report),
            report_types::status(report),
        )
    }

    /// Get duplicate registry statistics
    public fun get_registry_stats(registry: &DuplicateRegistry): (u64, u64) {
        duplicate_registry::get_stats(registry)
    }

    // ========== Admin/Triage Functions ==========

    /// Update report status
    /// This is typically called by triage committee or program owner
    /// after reviewing the report
    ///
    /// # Arguments
    /// * `report` - The report to update
    /// * `new_status` - New status value (1-6)
    ///
    /// # Status values:
    /// - 0: SUBMITTED (initial state)
    /// - 1: UNDER_REVIEW (being evaluated)
    /// - 2: ACCEPTED (valid vulnerability)
    /// - 3: REJECTED (invalid/out of scope)
    /// - 4: DUPLICATE (already reported)
    /// - 5: WITHDRAWN (researcher retracted)
    /// - 6: PAID (bounty awarded)
    ///
    /// # Panics
    /// - If status transition is invalid (enforces state machine)
    public entry fun update_report_status(
        report: &mut BugReport,
        new_status: u8,
        ctx: &TxContext,
    ) {
        report_crud::update_status(report, new_status, ctx);
    }

    /// Register a vulnerability signature in the duplicate registry
    /// This should be called when a report is accepted as valid
    ///
    /// # Arguments
    /// * `registry` - The duplicate registry
    /// * `report` - The report that was accepted
    ///
    /// # Behavior
    /// - Registers the vulnerability signature to prevent future duplicates
    /// - Should be called as part of the acceptance workflow
    ///
    /// # Panics
    /// - If signature is already registered
    public entry fun register_accepted_report(
        registry: &mut DuplicateRegistry,
        report: &BugReport,
    ) {
        let vulnerability_hash = *report_types::vulnerability_hash(report);
        let report_id = object::uid_to_inner(report_types::id(report));
        duplicate_registry::register_signature(registry, vulnerability_hash, report_id);
    }
}
