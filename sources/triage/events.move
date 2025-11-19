// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Event types for the DAO-based severity triage voting system.
/// This module defines all events emitted during the voting lifecycle.
module suiguard::triage_events {
    use sui::object::ID;
    use sui::event;

    // ======== Event Structs ========

    /// Emitted when a new triage vote is created
    public struct TriageVoteCreated has copy, drop {
        /// ID of the created vote
        vote_id: ID,
        /// ID of the report being triaged
        report_id: ID,
        /// ID of the bug bounty program
        program_id: ID,
        /// Address that created the vote
        creator: address,
        /// Epoch when voting ends
        voting_deadline: u64,
        /// Minimum stake required to finalize (in MIST)
        minimum_quorum: u64,
    }

    /// Emitted when a voter casts their vote
    public struct VoteCast has copy, drop {
        /// ID of the vote
        vote_id: ID,
        /// Address of the voter
        voter: address,
        /// Severity level chosen (0-4)
        severity_choice: u8,
        /// Amount of SUI staked (in MIST)
        stake_amount: u64,
        /// Epoch when the vote was cast
        voted_at: u64,
    }

    /// Emitted when a triage vote is finalized
    public struct TriageFinalized has copy, drop {
        /// ID of the vote
        vote_id: ID,
        /// ID of the report
        report_id: ID,
        /// Final determined severity level
        final_severity: u8,
        /// Total amount staked across all votes
        total_staked: u64,
        /// Amount in the reward pool (from slashing)
        reward_pool_amount: u64,
        /// Epoch when finalized
        finalized_at: u64,
    }

    /// Emitted when a voter claims their voting rewards
    public struct RewardClaimed has copy, drop {
        /// ID of the vote
        vote_id: ID,
        /// Address of the voter claiming
        voter: address,
        /// Amount of reward claimed (in MIST)
        reward_amount: u64,
        /// Epoch when claimed
        claimed_at: u64,
    }

    // ======== Event Emission Functions ========

    /// Emit a TriageVoteCreated event
    public(package) fun emit_vote_created(
        vote_id: ID,
        report_id: ID,
        program_id: ID,
        creator: address,
        voting_deadline: u64,
        minimum_quorum: u64,
    ) {
        event::emit(TriageVoteCreated {
            vote_id,
            report_id,
            program_id,
            creator,
            voting_deadline,
            minimum_quorum,
        });
    }

    /// Emit a VoteCast event
    public(package) fun emit_vote_cast(
        vote_id: ID,
        voter: address,
        severity_choice: u8,
        stake_amount: u64,
        voted_at: u64,
    ) {
        event::emit(VoteCast {
            vote_id,
            voter,
            severity_choice,
            stake_amount,
            voted_at,
        });
    }

    /// Emit a TriageFinalized event
    public(package) fun emit_triage_finalized(
        vote_id: ID,
        report_id: ID,
        final_severity: u8,
        total_staked: u64,
        reward_pool_amount: u64,
        finalized_at: u64,
    ) {
        event::emit(TriageFinalized {
            vote_id,
            report_id,
            final_severity,
            total_staked,
            reward_pool_amount,
            finalized_at,
        });
    }

    /// Emit a RewardClaimed event
    public(package) fun emit_reward_claimed(
        vote_id: ID,
        voter: address,
        reward_amount: u64,
        claimed_at: u64,
    ) {
        event::emit(RewardClaimed {
            vote_id,
            voter,
            reward_amount,
            claimed_at,
        });
    }

    // ======== Event Getters ========

    /// Get vote_id from TriageVoteCreated event
    public fun vote_created_vote_id(event: &TriageVoteCreated): ID {
        event.vote_id
    }

    /// Get report_id from TriageVoteCreated event
    public fun vote_created_report_id(event: &TriageVoteCreated): ID {
        event.report_id
    }

    /// Get vote_id from VoteCast event
    public fun vote_cast_vote_id(event: &VoteCast): ID {
        event.vote_id
    }

    /// Get voter from VoteCast event
    public fun vote_cast_voter(event: &VoteCast): address {
        event.voter
    }

    /// Get severity_choice from VoteCast event
    public fun vote_cast_severity_choice(event: &VoteCast): u8 {
        event.severity_choice
    }

    /// Get stake_amount from VoteCast event
    public fun vote_cast_stake_amount(event: &VoteCast): u64 {
        event.stake_amount
    }

    /// Get vote_id from TriageFinalized event
    public fun triage_finalized_vote_id(event: &TriageFinalized): ID {
        event.vote_id
    }

    /// Get final_severity from TriageFinalized event
    public fun triage_finalized_severity(event: &TriageFinalized): u8 {
        event.final_severity
    }

    /// Get total_staked from TriageFinalized event
    public fun triage_finalized_total_staked(event: &TriageFinalized): u64 {
        event.total_staked
    }

    /// Get reward_pool_amount from TriageFinalized event
    public fun triage_finalized_reward_pool(event: &TriageFinalized): u64 {
        event.reward_pool_amount
    }

    /// Get vote_id from RewardClaimed event
    public fun reward_claimed_vote_id(event: &RewardClaimed): ID {
        event.vote_id
    }

    /// Get voter from RewardClaimed event
    public fun reward_claimed_voter(event: &RewardClaimed): address {
        event.voter
    }

    /// Get reward_amount from RewardClaimed event
    public fun reward_claimed_amount(event: &RewardClaimed): u64 {
        event.reward_amount
    }
}
