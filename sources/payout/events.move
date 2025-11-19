// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Payout Events
/// Events emitted during payout lifecycle
module suiguard::payout_events {
    use sui::object::ID;
    use sui::event;

    /// Emitted when a payout is executed
    public struct PayoutExecuted has copy, drop {
        report_id: ID,
        program_id: ID,
        researcher: address,
        amount: u64,
        severity: u8,
        executed_at: u64,
    }

    /// Emitted when a split proposal is created
    public struct SplitProposalCreated has copy, drop {
        proposal_id: ID,
        report_id: ID,
        primary_researcher: address,
        total_amount: u64,
        num_recipients: u64,
        created_at: u64,
    }

    /// Emitted when a recipient approves a split
    public struct SplitApproved has copy, drop {
        proposal_id: ID,
        report_id: ID,
        recipient: address,
        approved_at: u64,
    }

    /// Emitted when a split payout is executed
    public struct SplitPayoutExecuted has copy, drop {
        proposal_id: ID,
        report_id: ID,
        total_amount: u64,
        num_recipients: u64,
        executed_at: u64,
    }

    /// Emitted when a split proposal is cancelled
    public struct SplitProposalCancelled has copy, drop {
        proposal_id: ID,
        report_id: ID,
        cancelled_by: address,
        cancelled_at: u64,
    }

    // ========== Event Emission Functions ==========

    public(package) fun emit_payout_executed(
        report_id: ID,
        program_id: ID,
        researcher: address,
        amount: u64,
        severity: u8,
        executed_at: u64,
    ) {
        event::emit(PayoutExecuted {
            report_id,
            program_id,
            researcher,
            amount,
            severity,
            executed_at,
        });
    }

    public(package) fun emit_split_proposal_created(
        proposal_id: ID,
        report_id: ID,
        primary_researcher: address,
        total_amount: u64,
        num_recipients: u64,
        created_at: u64,
    ) {
        event::emit(SplitProposalCreated {
            proposal_id,
            report_id,
            primary_researcher,
            total_amount,
            num_recipients,
            created_at,
        });
    }

    public(package) fun emit_split_approved(
        proposal_id: ID,
        report_id: ID,
        recipient: address,
        approved_at: u64,
    ) {
        event::emit(SplitApproved {
            proposal_id,
            report_id,
            recipient,
            approved_at,
        });
    }

    public(package) fun emit_split_payout_executed(
        proposal_id: ID,
        report_id: ID,
        total_amount: u64,
        num_recipients: u64,
        executed_at: u64,
    ) {
        event::emit(SplitPayoutExecuted {
            proposal_id,
            report_id,
            total_amount,
            num_recipients,
            executed_at,
        });
    }

    public(package) fun emit_split_proposal_cancelled(
        proposal_id: ID,
        report_id: ID,
        cancelled_by: address,
        cancelled_at: u64,
    ) {
        event::emit(SplitProposalCancelled {
            proposal_id,
            report_id,
            cancelled_by,
            cancelled_at,
        });
    }
}
