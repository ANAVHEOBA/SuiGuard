// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Core types for the DAO-based severity triage voting system.
/// This module defines the data structures for managing decentralized voting
/// on vulnerability report severity classifications.
module suiguard::triage_types {
    use sui::object::{Self, UID, ID};
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::tx_context::TxContext;

    // ======== Constants ========

    /// Standard voting period: 57,600 epochs (~48 hours at 3 seconds per epoch)
    const VOTING_PERIOD_EPOCHS: u64 = 57600;

    /// Urgent voting period: 7,200 epochs (~6 hours at 3 seconds per epoch)
    const URGENT_VOTING_PERIOD_EPOCHS: u64 = 7200;

    /// Default minimum quorum: 10,000 SUI (10,000 * 10^9 MIST)
    const DEFAULT_MINIMUM_QUORUM: u64 = 10_000_000_000_000;

    /// Urgent vote minimum quorum: 20,000 SUI (higher requirement for fast-track)
    const URGENT_MINIMUM_QUORUM: u64 = 20_000_000_000_000;

    /// Premium fee for urgent triage: 500 SUI (500 * 10^9 MIST)
    const URGENT_TRIAGE_FEE: u64 = 500_000_000_000;

    /// Slash percentage in basis points: 1000 = 10%
    const SLASH_PERCENTAGE_BP: u64 = 1000;

    /// Maximum basis points (100%)
    const BASIS_POINTS_MAX: u64 = 10000;

    // Vote status constants
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_FINALIZED: u8 = 1;
    const STATUS_CANCELLED: u8 = 2;

    // Severity level constants
    const SEVERITY_NONE: u8 = 0;
    const SEVERITY_LOW: u8 = 1;
    const SEVERITY_MEDIUM: u8 = 2;
    const SEVERITY_HIGH: u8 = 3;
    const SEVERITY_CRITICAL: u8 = 4;

    // ======== Error Codes ========

    const E_INVALID_SEVERITY: u64 = 1;
    const E_INVALID_STATUS: u64 = 2;
    const E_VOTING_ENDED: u64 = 3;
    const E_VOTING_NOT_ENDED: u64 = 4;
    const E_ALREADY_VOTED: u64 = 5;
    const E_NOT_VOTED: u64 = 6;
    const E_QUORUM_NOT_MET: u64 = 7;
    const E_ALREADY_CLAIMED: u64 = 8;
    const E_NOT_MAJORITY_VOTER: u64 = 9;
    const E_VOTE_NOT_FINALIZED: u64 = 10;
    const E_INSUFFICIENT_PREMIUM: u64 = 11;
    const E_NOT_EMERGENCY_ADMIN: u64 = 12;

    // ======== Structs ========

    /// Emergency admin capability for fast-tracking critical votes
    /// Only holders of this capability can use emergency_fast_track()
    public struct EmergencyAdminCap has key, store {
        id: UID,
    }

    /// Record of an individual voter's participation in a triage vote
    public struct VoteRecord has store, drop, copy {
        /// Address of the voter
        voter: address,
        /// Severity level chosen (0-4)
        severity_choice: u8,
        /// Amount of SUI staked (in MIST)
        stake_amount: u64,
        /// Epoch when the vote was cast
        voted_at: u64,
        /// Whether the voter has claimed their reward
        claimed_reward: bool,
    }

    /// Main voting object for severity triage
    public struct TriageVote has key, store {
        id: UID,
        /// ID of the vulnerability report being triaged
        report_id: ID,
        /// ID of the bug bounty program
        program_id: ID,
        /// Address of the vote creator
        creator: address,
        /// Epoch when voting ends
        voting_deadline: u64,
        /// Minimum stake required to finalize (in MIST)
        minimum_quorum: u64,
        /// Total SUI staked across all votes
        total_staked: u64,
        /// Distribution of stakes per severity level (severity -> total_stake)
        vote_distribution: VecMap<u8, u64>,
        /// Table mapping voter address to their vote record
        voters: Table<address, VoteRecord>,
        /// Current status of the vote (0=ACTIVE, 1=FINALIZED, 2=CANCELLED)
        status: u8,
        /// Final determined severity (only set after finalization)
        final_severity: u8,
        /// Reward pool from slashed minority stakes
        reward_pool: Balance<SUI>,
        /// Whether this is an urgent/expedited vote (6-hour deadline)
        is_urgent: bool,
        /// Premium fee paid for urgent triage (in MIST)
        premium_paid: u64,
    }

    /// Shared registry mapping report IDs to their triage vote IDs
    public struct TriageRegistry has key {
        id: UID,
        /// Mapping from report_id to vote_id
        votes: Table<ID, ID>,
    }

    // ======== Constructor Functions ========

    /// Create a new VoteRecord
    public(package) fun new_vote_record(
        voter: address,
        severity_choice: u8,
        stake_amount: u64,
        voted_at: u64,
    ): VoteRecord {
        assert!(severity_choice <= SEVERITY_CRITICAL, E_INVALID_SEVERITY);
        VoteRecord {
            voter,
            severity_choice,
            stake_amount,
            voted_at,
            claimed_reward: false,
        }
    }

    /// Create a new TriageVote object
    public(package) fun new_triage_vote(
        report_id: ID,
        program_id: ID,
        creator: address,
        current_epoch: u64,
        minimum_quorum: u64,
        ctx: &mut TxContext,
    ): TriageVote {
        let mut vote_distribution = vec_map::empty<u8, u64>();

        // Initialize distribution for all severity levels
        vec_map::insert(&mut vote_distribution, SEVERITY_NONE, 0);
        vec_map::insert(&mut vote_distribution, SEVERITY_LOW, 0);
        vec_map::insert(&mut vote_distribution, SEVERITY_MEDIUM, 0);
        vec_map::insert(&mut vote_distribution, SEVERITY_HIGH, 0);
        vec_map::insert(&mut vote_distribution, SEVERITY_CRITICAL, 0);

        TriageVote {
            id: object::new(ctx),
            report_id,
            program_id,
            creator,
            voting_deadline: current_epoch + VOTING_PERIOD_EPOCHS,
            minimum_quorum,
            total_staked: 0,
            vote_distribution,
            voters: table::new(ctx),
            status: STATUS_ACTIVE,
            final_severity: SEVERITY_NONE,
            reward_pool: balance::zero<SUI>(),
            is_urgent: false,
            premium_paid: 0,
        }
    }

    /// Create a new urgent TriageVote object with expedited timeline
    public(package) fun new_urgent_triage_vote(
        report_id: ID,
        program_id: ID,
        creator: address,
        current_epoch: u64,
        premium: Balance<SUI>,
        ctx: &mut TxContext,
    ): TriageVote {
        let mut vote_distribution = vec_map::empty<u8, u64>();

        // Initialize distribution for all severity levels
        vec_map::insert(&mut vote_distribution, SEVERITY_NONE, 0);
        vec_map::insert(&mut vote_distribution, SEVERITY_LOW, 0);
        vec_map::insert(&mut vote_distribution, SEVERITY_MEDIUM, 0);
        vec_map::insert(&mut vote_distribution, SEVERITY_HIGH, 0);
        vec_map::insert(&mut vote_distribution, SEVERITY_CRITICAL, 0);

        let premium_amount = balance::value(&premium);

        TriageVote {
            id: object::new(ctx),
            report_id,
            program_id,
            creator,
            voting_deadline: current_epoch + URGENT_VOTING_PERIOD_EPOCHS,
            minimum_quorum: URGENT_MINIMUM_QUORUM,
            total_staked: 0,
            vote_distribution,
            voters: table::new(ctx),
            status: STATUS_ACTIVE,
            final_severity: SEVERITY_NONE,
            reward_pool: premium, // Premium goes into reward pool
            is_urgent: true,
            premium_paid: premium_amount,
        }
    }

    /// Create a new TriageRegistry
    public(package) fun new_registry(ctx: &mut TxContext): TriageRegistry {
        TriageRegistry {
            id: object::new(ctx),
            votes: table::new(ctx),
        }
    }

    /// Create and share a new TriageRegistry
    /// This is used by the init function to bypass the transfer restriction
    public(package) fun create_and_share_registry(ctx: &mut TxContext) {
        use sui::transfer;
        let registry = new_registry(ctx);
        transfer::share_object(registry);
    }

    /// Create a new EmergencyAdminCap
    /// Should be called during init to create admin capabilities
    public(package) fun new_emergency_admin_cap(ctx: &mut TxContext): EmergencyAdminCap {
        EmergencyAdminCap {
            id: object::new(ctx),
        }
    }

    // ======== Getters ========

    /// Get the vote ID
    public fun id(vote: &TriageVote): ID {
        object::uid_to_inner(&vote.id)
    }

    /// Get the report ID
    public fun report_id(vote: &TriageVote): ID {
        vote.report_id
    }

    /// Get the program ID
    public fun program_id(vote: &TriageVote): ID {
        vote.program_id
    }

    /// Get the creator address
    public fun creator(vote: &TriageVote): address {
        vote.creator
    }

    /// Get the voting deadline epoch
    public fun voting_deadline(vote: &TriageVote): u64 {
        vote.voting_deadline
    }

    /// Get the minimum quorum
    public fun minimum_quorum(vote: &TriageVote): u64 {
        vote.minimum_quorum
    }

    /// Get the total staked amount
    public fun total_staked(vote: &TriageVote): u64 {
        vote.total_staked
    }

    /// Get the vote status
    public fun status(vote: &TriageVote): u8 {
        vote.status
    }

    /// Get the final severity (only valid after finalization)
    public fun final_severity(vote: &TriageVote): u8 {
        vote.final_severity
    }

    /// Get the reward pool value
    public fun reward_pool_value(vote: &TriageVote): u64 {
        balance::value(&vote.reward_pool)
    }

    /// Get the stake for a specific severity level
    public fun get_severity_stake(vote: &TriageVote, severity: u8): u64 {
        assert!(severity <= SEVERITY_CRITICAL, E_INVALID_SEVERITY);
        *vec_map::get(&vote.vote_distribution, &severity)
    }

    /// Check if a voter has voted
    public fun has_voted(vote: &TriageVote, voter: address): bool {
        table::contains(&vote.voters, voter)
    }

    /// Get a voter's record (returns Option-like values)
    public fun get_voter_record(vote: &TriageVote, voter: address): &VoteRecord {
        assert!(table::contains(&vote.voters, voter), E_NOT_VOTED);
        table::borrow(&vote.voters, voter)
    }

    /// Check if voting is active
    public fun is_active(vote: &TriageVote): bool {
        vote.status == STATUS_ACTIVE
    }

    /// Check if voting is finalized
    public fun is_finalized(vote: &TriageVote): bool {
        vote.status == STATUS_FINALIZED
    }

    /// Check if vote is urgent/expedited
    public fun is_urgent(vote: &TriageVote): bool {
        vote.is_urgent
    }

    /// Get premium paid for urgent triage
    public fun premium_paid(vote: &TriageVote): u64 {
        vote.premium_paid
    }

    /// Get urgent triage fee constant
    public fun urgent_triage_fee(): u64 {
        URGENT_TRIAGE_FEE
    }

    /// Get urgent minimum quorum constant
    public fun urgent_minimum_quorum(): u64 {
        URGENT_MINIMUM_QUORUM
    }

    /// Get urgent voting period constant
    public fun urgent_voting_period_epochs(): u64 {
        URGENT_VOTING_PERIOD_EPOCHS
    }

    /// Get vote record fields
    public fun vote_record_voter(record: &VoteRecord): address {
        record.voter
    }

    public fun vote_record_severity_choice(record: &VoteRecord): u8 {
        record.severity_choice
    }

    public fun vote_record_stake_amount(record: &VoteRecord): u64 {
        record.stake_amount
    }

    public fun vote_record_voted_at(record: &VoteRecord): u64 {
        record.voted_at
    }

    public fun vote_record_claimed_reward(record: &VoteRecord): bool {
        record.claimed_reward
    }

    /// Get vote ID for a report from registry
    public fun get_vote_id_for_report(registry: &TriageRegistry, report_id: ID): ID {
        *table::borrow(&registry.votes, report_id)
    }

    /// Check if report has a vote
    public fun has_vote_for_report(registry: &TriageRegistry, report_id: ID): bool {
        table::contains(&registry.votes, report_id)
    }

    // ======== Package-Only Setters ========

    /// Add a voter's record
    public(package) fun add_voter(
        vote: &mut TriageVote,
        voter: address,
        severity_choice: u8,
        stake_amount: u64,
        current_epoch: u64,
    ) {
        assert!(!table::contains(&vote.voters, voter), E_ALREADY_VOTED);
        assert!(severity_choice <= SEVERITY_CRITICAL, E_INVALID_SEVERITY);

        let record = new_vote_record(voter, severity_choice, stake_amount, current_epoch);
        table::add(&mut vote.voters, voter, record);
    }

    /// Update vote distribution for a severity level
    public(package) fun add_to_severity_stake(
        vote: &mut TriageVote,
        severity: u8,
        amount: u64,
    ) {
        assert!(severity <= SEVERITY_CRITICAL, E_INVALID_SEVERITY);
        let current = vec_map::get_mut(&mut vote.vote_distribution, &severity);
        *current = *current + amount;
    }

    /// Increase total staked amount
    public(package) fun add_to_total_staked(vote: &mut TriageVote, amount: u64) {
        vote.total_staked = vote.total_staked + amount;
    }

    /// Set the final severity
    public(package) fun set_final_severity(vote: &mut TriageVote, severity: u8) {
        assert!(severity <= SEVERITY_CRITICAL, E_INVALID_SEVERITY);
        vote.final_severity = severity;
    }

    /// Set the vote status
    public(package) fun set_status(vote: &mut TriageVote, new_status: u8) {
        assert!(new_status <= STATUS_CANCELLED, E_INVALID_STATUS);
        vote.status = new_status;
    }

    /// Fast-track a vote by setting its deadline to urgent timeline
    /// Can only be called by emergency admin
    public(package) fun fast_track_vote(vote: &mut TriageVote, current_epoch: u64) {
        // Set urgent parameters
        vote.is_urgent = true;
        vote.voting_deadline = current_epoch + URGENT_VOTING_PERIOD_EPOCHS;
        vote.minimum_quorum = URGENT_MINIMUM_QUORUM;
    }

    /// Add to reward pool
    public(package) fun add_to_reward_pool(vote: &mut TriageVote, amount: Balance<SUI>) {
        balance::join(&mut vote.reward_pool, amount);
    }

    /// Take from reward pool
    public(package) fun take_from_reward_pool(vote: &mut TriageVote, amount: u64): Balance<SUI> {
        balance::split(&mut vote.reward_pool, amount)
    }

    /// Mark voter as having claimed reward
    public(package) fun mark_reward_claimed(vote: &mut TriageVote, voter: address) {
        assert!(table::contains(&vote.voters, voter), E_NOT_VOTED);
        let record = table::borrow_mut(&mut vote.voters, voter);
        assert!(!record.claimed_reward, E_ALREADY_CLAIMED);
        record.claimed_reward = true;
    }

    /// Register a vote in the registry
    public(package) fun register_vote(
        registry: &mut TriageRegistry,
        report_id: ID,
        vote_id: ID,
    ) {
        table::add(&mut registry.votes, report_id, vote_id);
    }

    // ======== Borrow Functions ========

    /// Borrow mutable voter record
    public(package) fun borrow_voter_record_mut(
        vote: &mut TriageVote,
        voter: address,
    ): &mut VoteRecord {
        assert!(table::contains(&vote.voters, voter), E_NOT_VOTED);
        table::borrow_mut(&mut vote.voters, voter)
    }

    /// Borrow vote distribution
    public(package) fun borrow_vote_distribution(vote: &TriageVote): &VecMap<u8, u64> {
        &vote.vote_distribution
    }

    // ======== Constant Getters ========

    /// Get the voting period in epochs
    public fun voting_period_epochs(): u64 {
        VOTING_PERIOD_EPOCHS
    }

    /// Get the default minimum quorum
    public fun default_minimum_quorum(): u64 {
        DEFAULT_MINIMUM_QUORUM
    }

    /// Get the slash percentage in basis points
    public fun slash_percentage_bp(): u64 {
        SLASH_PERCENTAGE_BP
    }

    /// Get the maximum basis points value
    public fun basis_points_max(): u64 {
        BASIS_POINTS_MAX
    }

    // Status constants
    public fun status_active(): u8 { STATUS_ACTIVE }
    public fun status_finalized(): u8 { STATUS_FINALIZED }
    public fun status_cancelled(): u8 { STATUS_CANCELLED }

    // Severity constants
    public fun severity_none(): u8 { SEVERITY_NONE }
    public fun severity_low(): u8 { SEVERITY_LOW }
    public fun severity_medium(): u8 { SEVERITY_MEDIUM }
    public fun severity_high(): u8 { SEVERITY_HIGH }
    public fun severity_critical(): u8 { SEVERITY_CRITICAL }

    // ======== Test-Only Functions ========

    #[test_only]
    public fun new_for_testing(
        report_id: ID,
        program_id: ID,
        creator: address,
        current_epoch: u64,
        minimum_quorum: u64,
        ctx: &mut TxContext,
    ): TriageVote {
        new_triage_vote(report_id, program_id, creator, current_epoch, minimum_quorum, ctx)
    }

    #[test_only]
    /// Create vote with custom voting period for testing
    public fun new_with_custom_deadline(
        report_id: ID,
        program_id: ID,
        creator: address,
        current_epoch: u64,
        minimum_quorum: u64,
        voting_period: u64,
        ctx: &mut TxContext,
    ): TriageVote {
        let mut vote = new_triage_vote(report_id, program_id, creator, current_epoch, minimum_quorum, ctx);
        vote.voting_deadline = current_epoch + voting_period;
        vote
    }

    #[test_only]
    public fun destroy_for_testing(vote: TriageVote) {
        let TriageVote {
            id,
            report_id: _,
            program_id: _,
            creator: _,
            voting_deadline: _,
            minimum_quorum: _,
            total_staked: _,
            vote_distribution: _,
            voters,
            status: _,
            final_severity: _,
            reward_pool,
            is_urgent: _,
            premium_paid: _,
        } = vote;

        object::delete(id);
        table::drop(voters);
        balance::destroy_for_testing(reward_pool);
    }
}
