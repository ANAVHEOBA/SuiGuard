/// CRUD operations for bug reports
module suiguard::report_crud {
    use std::option::{Self, Option};
    use sui::object::{Self, ID};
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::sui::SUI;
    use sui::tx_context::{Self, TxContext};
    use suiguard::report_types::{Self, BugReport};
    use suiguard::report_validation;
    use suiguard::report_events;
    use suiguard::duplicate_registry::{Self, DuplicateRegistry};

    // ========== Create Operations ==========

    /// Create a new bug report
    ///
    /// # Arguments
    /// * `program_id` - ID of the bounty program this report targets
    /// * `severity` - Vulnerability severity (0-4)
    /// * `category` - Vulnerability category (0-7)
    /// * `walrus_blob_id` - Walrus blob ID containing encrypted report details
    /// * `seal_policy_id` - Optional Seal policy ID for time-locked disclosure
    /// * `affected_targets` - List of affected contract addresses/modules
    /// * `vulnerability_hash` - Hash of vulnerability signature for duplicate detection
    /// * `submission_fee` - Anti-spam fee (refunded if report is valid)
    ///
    /// # Returns
    /// A new BugReport object
    public(package) fun create(
        program_id: ID,
        severity: u8,
        category: u8,
        walrus_blob_id: vector<u8>,
        seal_policy_id: Option<vector<u8>>,
        affected_targets: vector<vector<u8>>,
        vulnerability_hash: vector<u8>,
        submission_fee: Coin<SUI>,
        ctx: &mut TxContext,
    ): BugReport {
        // Validate inputs
        let fee_amount = coin::value(&submission_fee);
        report_validation::validate_bug_report_submission(
            severity,
            category,
            &walrus_blob_id,
            &vulnerability_hash,
            fee_amount,
        );

        // Get researcher address and timestamp
        let researcher = tx_context::sender(ctx);
        let submitted_at = tx_context::epoch(ctx);

        // Create report object
        let report = report_types::new(
            program_id,
            researcher,
            severity,
            category,
            walrus_blob_id,
            seal_policy_id,
            affected_targets,
            vulnerability_hash,
            coin::into_balance(submission_fee),
            submitted_at,
            ctx,
        );

        // Emit event
        let report_id = object::uid_to_inner(report_types::id(&report));
        report_events::emit_report_submitted(
            report_id,
            program_id,
            researcher,
            severity,
            category,
            *report_types::walrus_blob_id(&report),
            fee_amount,
            submitted_at,
        );

        report
    }

    // ========== Update Operations ==========

    /// Withdraw a bug report before it has been reviewed
    /// Returns the submission fee to the researcher and destroys the report
    ///
    /// # Arguments
    /// * `report` - The bug report to withdraw
    /// * `registry` - Duplicate registry to clean up signature if registered
    /// * `ctx` - Transaction context
    ///
    /// # Returns
    /// The submission fee as a Coin<SUI>
    public(package) fun withdraw(
        report: BugReport,
        registry: &mut DuplicateRegistry,
        ctx: &mut TxContext,
    ): Coin<SUI> {
        // Validate researcher owns this report
        let researcher = tx_context::sender(ctx);
        report_validation::validate_researcher(report_types::researcher(&report), researcher);

        // Validate report can be withdrawn (must be in SUBMITTED status)
        report_validation::validate_can_withdraw(report_types::status(&report));

        // Extract data before destroying
        let report_id = object::uid_to_inner(report_types::id(&report));
        let program_id = report_types::program_id(&report);
        let vulnerability_hash = *report_types::vulnerability_hash(&report);

        // Update status to WITHDRAWN before destruction
        let mut report_mut = report;
        report_types::set_status(&mut report_mut, report_types::status_withdrawn());
        report_types::set_updated_at(&mut report_mut, tx_context::epoch(ctx));

        // Extract and return submission fee
        let fee = report_types::withdraw_fee(&mut report_mut);
        let fee_amount = balance::value(&fee);

        // Emit withdrawal event
        report_events::emit_report_withdrawn(
            report_id,
            program_id,
            researcher,
            fee_amount,
        );

        // Clean up duplicate registry if signature was registered
        duplicate_registry::unregister_signature(registry, &vulnerability_hash);

        // Destroy the report (balance is now empty)
        report_types::destroy_empty(report_mut);

        // Return fee as coin
        coin::from_balance(fee, ctx)
    }

    /// Mark a report as duplicate of an original report
    ///
    /// # Arguments
    /// * `report` - The report to mark as duplicate
    /// * `original_report_id` - ID of the original report
    /// * `registry` - Duplicate registry to update statistics
    /// * `ctx` - Transaction context
    public(package) fun mark_duplicate(
        report: &mut BugReport,
        original_report_id: ID,
        registry: &mut DuplicateRegistry,
        ctx: &TxContext,
    ) {
        // Validate report is not already marked as duplicate
        report_validation::validate_not_duplicate(report_types::status(report));

        // Validate status transition
        let old_status = report_types::status(report);
        let new_status = report_types::status_duplicate();
        report_validation::validate_status_transition(old_status, new_status);

        // Update report
        report_types::set_status(report, new_status);
        report_types::set_duplicate_of(report, original_report_id);
        report_types::set_updated_at(report, tx_context::epoch(ctx));

        // Update registry statistics
        duplicate_registry::increment_duplicates(registry);

        // Emit event
        let report_id = object::uid_to_inner(report_types::id(report));
        let program_id = report_types::program_id(report);
        let researcher = report_types::researcher(report);

        report_events::emit_report_marked_duplicate(
            report_id,
            program_id,
            original_report_id,
            researcher,
        );
    }

    /// Update the status of a bug report
    ///
    /// # Arguments
    /// * `report` - The report to update
    /// * `new_status` - New status value
    /// * `ctx` - Transaction context
    public(package) fun update_status(
        report: &mut BugReport,
        new_status: u8,
        ctx: &TxContext,
    ) {
        let old_status = report_types::status(report);

        // Validate the status transition is allowed
        report_validation::validate_status_transition(old_status, new_status);

        // Update status
        report_types::set_status(report, new_status);
        report_types::set_updated_at(report, tx_context::epoch(ctx));

        // Emit event
        let report_id = object::uid_to_inner(report_types::id(report));
        let program_id = report_types::program_id(report);

        report_events::emit_report_status_changed(
            report_id,
            program_id,
            old_status,
            new_status,
            tx_context::epoch(ctx),
        );
    }

    /// Link a TEE attestation to a bug report
    /// This proves the report was generated in a secure enclave
    ///
    /// # Arguments
    /// * `report` - The report to link attestation to
    /// * `attestation_id` - ID of the Nautilus attestation object
    /// * `ctx` - Transaction context
    public(package) fun link_attestation(
        report: &mut BugReport,
        attestation_id: ID,
        ctx: &TxContext,
    ) {
        // Validate researcher owns this report
        let researcher = tx_context::sender(ctx);
        report_validation::validate_researcher(report_types::researcher(report), researcher);

        // Link attestation
        report_types::set_attestation_id(report, attestation_id);
        report_types::set_updated_at(report, tx_context::epoch(ctx));

        // Emit event
        let report_id = object::uid_to_inner(report_types::id(report));

        report_events::emit_attestation_linked(
            report_id,
            attestation_id,
            researcher,
        );
    }

    // ========== Query Operations ==========

    /// Check if a report is in a terminal state (cannot be modified)
    public fun is_terminal_state(report: &BugReport): bool {
        let status = report_types::status(report);
        // REJECTED=3, DUPLICATE=4, WITHDRAWN=5, PAID=6 are terminal
        status == 3 || status == 4 || status == 5 || status == 6
    }

    /// Check if a report can be withdrawn
    public fun can_withdraw(report: &BugReport): bool {
        report_types::status(report) == 0 // STATUS_SUBMITTED
    }

    /// Check if a report is pending review
    public fun is_pending_review(report: &BugReport): bool {
        let status = report_types::status(report);
        status == 0 || status == 1 // SUBMITTED or UNDER_REVIEW
    }

    /// Check if a report was accepted and should receive payout
    public fun should_receive_payout(report: &BugReport): bool {
        report_types::status(report) == 2 // ACCEPTED
    }

    /// Get the original report ID if this is a duplicate
    public fun get_duplicate_original(report: &BugReport): Option<ID> {
        if (report_types::is_duplicate(report)) {
            *report_types::duplicate_of(report)
        } else {
            option::none()
        }
    }
}
