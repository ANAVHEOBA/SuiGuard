// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Payout Data Models
/// Defines structures for bounty payouts and split payments
module suiguard::payout_types {
    use std::option::{Self, Option};
    use std::vector;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::TxContext;
    use sui::vec_set::{Self, VecSet};

    /// Split recipient information
    public struct SplitRecipient has store, copy, drop {
        /// Address of the recipient
        recipient: address,
        /// Percentage in basis points (100 = 1%, 10000 = 100%)
        percentage_bp: u64,
        /// Whether this recipient has approved the split
        approved: bool,
    }

    /// Split payment proposal
    /// Allows primary researcher to split rewards with co-finders
    public struct SplitProposal has key, store {
        id: UID,
        /// ID of the bug report this split is for
        report_id: ID,
        /// Primary researcher who created the proposal
        primary_researcher: address,
        /// List of recipients and their splits
        recipients: vector<SplitRecipient>,
        /// Total amount to be split (in MIST)
        total_amount: u64,
        /// Whether all parties have approved
        all_approved: bool,
        /// Whether the split has been executed
        executed: bool,
        /// When the proposal was created
        created_at: u64,
        /// When the split was executed (if executed)
        executed_at: Option<u64>,
    }

    // ========== Error Codes ==========

    const E_INVALID_TOTAL_PERCENTAGE: u64 = 5000;
    const E_RECIPIENT_NOT_FOUND: u64 = 5001;
    const E_ALREADY_APPROVED: u64 = 5002;
    const E_NOT_ALL_APPROVED: u64 = 5003;
    const E_ALREADY_EXECUTED: u64 = 5004;
    const E_INVALID_PERCENTAGE: u64 = 5005;
    const E_DUPLICATE_RECIPIENT: u64 = 5006;
    const E_NO_RECIPIENTS: u64 = 5007;

    /// Basis points maximum (100%)
    const BASIS_POINTS_MAX: u64 = 10000;

    // ========== Constructor Functions ==========

    /// Create a new SplitRecipient
    public(package) fun new_split_recipient(
        recipient: address,
        percentage_bp: u64,
    ): SplitRecipient {
        assert!(percentage_bp > 0 && percentage_bp <= BASIS_POINTS_MAX, E_INVALID_PERCENTAGE);
        SplitRecipient {
            recipient,
            percentage_bp,
            approved: false,
        }
    }

    /// Create a new SplitProposal
    public(package) fun new_split_proposal(
        report_id: ID,
        primary_researcher: address,
        recipients: vector<SplitRecipient>,
        total_amount: u64,
        created_at: u64,
        ctx: &mut TxContext,
    ): SplitProposal {
        // Validate there are recipients
        assert!(!vector::is_empty(&recipients), E_NO_RECIPIENTS);

        // Validate no duplicate recipients
        let mut seen = vec_set::empty<address>();
        let mut i = 0;
        let len = vector::length(&recipients);
        while (i < len) {
            let recipient = vector::borrow(&recipients, i);
            assert!(!vec_set::contains(&seen, &recipient.recipient), E_DUPLICATE_RECIPIENT);
            vec_set::insert(&mut seen, recipient.recipient);
            i = i + 1;
        };

        // Validate total percentage = 100%
        validate_total_percentage(&recipients);

        SplitProposal {
            id: object::new(ctx),
            report_id,
            primary_researcher,
            recipients,
            total_amount,
            all_approved: false,
            executed: false,
            created_at,
            executed_at: option::none(),
        }
    }

    /// Validate that total percentage equals 100%
    fun validate_total_percentage(recipients: &vector<SplitRecipient>) {
        let mut total = 0u64;
        let mut i = 0;
        let len = vector::length(recipients);
        while (i < len) {
            let recipient = vector::borrow(recipients, i);
            total = total + recipient.percentage_bp;
            i = i + 1;
        };
        assert!(total == BASIS_POINTS_MAX, E_INVALID_TOTAL_PERCENTAGE);
    }

    // ========== Getters ==========

    public fun id(proposal: &SplitProposal): &UID {
        &proposal.id
    }

    public fun report_id(proposal: &SplitProposal): ID {
        proposal.report_id
    }

    public fun primary_researcher(proposal: &SplitProposal): address {
        proposal.primary_researcher
    }

    public fun recipients(proposal: &SplitProposal): &vector<SplitRecipient> {
        &proposal.recipients
    }

    public fun total_amount(proposal: &SplitProposal): u64 {
        proposal.total_amount
    }

    public fun all_approved(proposal: &SplitProposal): bool {
        proposal.all_approved
    }

    public fun executed(proposal: &SplitProposal): bool {
        proposal.executed
    }

    public fun created_at(proposal: &SplitProposal): u64 {
        proposal.created_at
    }

    public fun executed_at(proposal: &SplitProposal): Option<u64> {
        proposal.executed_at
    }

    // === SplitRecipient Getters ===

    public fun recipient_address(recipient: &SplitRecipient): address {
        recipient.recipient
    }

    public fun recipient_percentage_bp(recipient: &SplitRecipient): u64 {
        recipient.percentage_bp
    }

    public fun recipient_approved(recipient: &SplitRecipient): bool {
        recipient.approved
    }

    // ========== Mutable Functions (package-only) ==========

    /// Approve a split for a specific recipient
    public(package) fun approve_recipient(proposal: &mut SplitProposal, recipient_addr: address) {
        assert!(!proposal.executed, E_ALREADY_EXECUTED);

        // Find the recipient and mark as approved
        let mut found = false;
        let mut i = 0;
        let len = vector::length(&proposal.recipients);
        while (i < len) {
            let recipient = vector::borrow_mut(&mut proposal.recipients, i);
            if (recipient.recipient == recipient_addr) {
                assert!(!recipient.approved, E_ALREADY_APPROVED);
                recipient.approved = true;
                found = true;
                break
            };
            i = i + 1;
        };

        assert!(found, E_RECIPIENT_NOT_FOUND);

        // Check if all approved
        let mut all_approved = true;
        let mut j = 0;
        while (j < len) {
            let recipient = vector::borrow(&proposal.recipients, j);
            if (!recipient.approved) {
                all_approved = false;
                break
            };
            j = j + 1;
        };

        proposal.all_approved = all_approved;
    }

    /// Mark the split as executed
    public(package) fun mark_executed(proposal: &mut SplitProposal, timestamp: u64) {
        assert!(proposal.all_approved, E_NOT_ALL_APPROVED);
        assert!(!proposal.executed, E_ALREADY_EXECUTED);
        proposal.executed = true;
        proposal.executed_at = option::some(timestamp);
    }

    /// Calculate the amount for a specific recipient
    public(package) fun calculate_recipient_amount(
        proposal: &SplitProposal,
        recipient_addr: address,
    ): u64 {
        let mut i = 0;
        let len = vector::length(&proposal.recipients);
        while (i < len) {
            let recipient = vector::borrow(&proposal.recipients, i);
            if (recipient.recipient == recipient_addr) {
                return (proposal.total_amount * recipient.percentage_bp) / BASIS_POINTS_MAX
            };
            i = i + 1;
        };
        0
    }

    /// Check if a recipient exists in the proposal
    public(package) fun has_recipient(proposal: &SplitProposal, recipient_addr: address): bool {
        let mut i = 0;
        let len = vector::length(&proposal.recipients);
        while (i < len) {
            let recipient = vector::borrow(&proposal.recipients, i);
            if (recipient.recipient == recipient_addr) {
                return true
            };
            i = i + 1;
        };
        false
    }

    /// Destroy a split proposal (package-only)
    public(package) fun destroy(proposal: SplitProposal) {
        let SplitProposal {
            id,
            report_id: _,
            primary_researcher: _,
            recipients: _,
            total_amount: _,
            all_approved: _,
            executed: _,
            created_at: _,
            executed_at: _,
        } = proposal;
        object::delete(id);
    }

    // ========== Test-Only Functions ==========

    #[test_only]
    public fun test_new_split_recipient(recipient: address, percentage_bp: u64): SplitRecipient {
        new_split_recipient(recipient, percentage_bp)
    }

    #[test_only]
    public fun destroy_for_testing(proposal: SplitProposal) {
        destroy(proposal)
    }

    // ========== Constants ==========

    public fun basis_points_max(): u64 { BASIS_POINTS_MAX }
}
