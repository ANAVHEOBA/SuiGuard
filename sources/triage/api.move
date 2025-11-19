// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Public API for the DAO-based severity triage voting system.
/// This module provides entry functions for creating votes, casting votes,
/// finalizing results, and claiming rewards, as well as view functions
/// for querying vote state.
module suiguard::triage_api {
    use std::vector;
    use sui::object::{Self, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance;
    use sui::sui::SUI;
    use sui::transfer;

    use suiguard::triage_types::{Self, TriageVote, TriageRegistry, EmergencyAdminCap};
    use suiguard::triage_voting;
    use suiguard::triage_rewards;
    use suiguard::triage_events;

    // ======== Error Codes ========

    const E_INVALID_QUORUM: u64 = 300;
    const E_INSUFFICIENT_STAKE: u64 = 301;
    const E_NOT_AUTHORIZED: u64 = 302;
    const E_VOTE_ALREADY_EXISTS: u64 = 303;
    const E_INSUFFICIENT_PREMIUM: u64 = 304;

    // ======== Entry Functions ========

    /// Create a new triage vote for a vulnerability report
    /// Can only be called by report owner or platform admin
    /// The created vote is transferred to the creator and registered in the registry
    public entry fun create_triage_vote(
        registry: &mut TriageRegistry,
        report_id: ID,
        program_id: ID,
        minimum_quorum: u64,
        ctx: &mut TxContext,
    ) {
        // Validate minimum quorum is reasonable (at least 1 SUI)
        assert!(minimum_quorum >= 1_000_000_000, E_INVALID_QUORUM);

        let creator = tx_context::sender(ctx);

        // Create the vote
        let vote = triage_voting::create_vote(
            report_id,
            program_id,
            creator,
            minimum_quorum,
            ctx,
        );

        let vote_id = triage_types::id(&vote);

        // Register in the registry
        triage_types::register_vote(registry, report_id, vote_id);

        // Share the vote object so anyone can vote
        transfer::public_share_object(vote);
    }

    /// Create an urgent/expedited triage vote for time-sensitive vulnerabilities
    /// Requires premium payment (500 SUI) for 6-hour voting period
    /// Has higher quorum requirement (20,000 SUI) than standard votes
    public entry fun create_urgent_triage(
        registry: &mut TriageRegistry,
        report_id: ID,
        program_id: ID,
        premium_payment: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let creator = tx_context::sender(ctx);

        // Validate premium payment is sufficient
        let premium_amount = coin::value(&premium_payment);
        assert!(premium_amount >= triage_types::urgent_triage_fee(), E_INSUFFICIENT_PREMIUM);

        // Convert coin to balance
        let premium_balance = coin::into_balance(premium_payment);

        // Create the urgent vote
        let vote = triage_voting::create_urgent_vote(
            report_id,
            program_id,
            creator,
            premium_balance,
            ctx,
        );

        let vote_id = triage_types::id(&vote);

        // Register in the registry
        triage_types::register_vote(registry, report_id, vote_id);

        // Share the vote object so anyone can vote
        transfer::public_share_object(vote);
    }

    /// Emergency fast-track an existing vote
    /// Can only be called by emergency admin
    /// Converts standard vote to urgent timeline when active exploit detected
    public entry fun emergency_fast_track(
        _admin_cap: &EmergencyAdminCap,
        vote: &mut TriageVote,
        ctx: &TxContext,
    ) {
        let current_epoch = tx_context::epoch(ctx);

        // Fast-track the vote (reduces deadline to 6 hours)
        triage_types::fast_track_vote(vote, current_epoch);

        // Emit event (reusing vote created event with updated params)
        triage_events::emit_vote_created(
            triage_types::id(vote),
            triage_types::report_id(vote),
            triage_types::program_id(vote),
            triage_types::creator(vote),
            triage_types::voting_deadline(vote),
            triage_types::minimum_quorum(vote),
        );
    }

    /// Cast a vote on a triage decision
    /// Anyone can vote by staking SUI tokens
    /// The stake is locked until the vote is finalized
    public entry fun cast_vote(
        vote: &mut TriageVote,
        severity_choice: u8,
        stake_coin: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let voter = tx_context::sender(ctx);

        // Validate stake amount is non-zero
        let stake_amount = coin::value(&stake_coin);
        assert!(stake_amount > 0, E_INSUFFICIENT_STAKE);

        // Convert coin to balance
        let stake_balance = coin::into_balance(stake_coin);

        // Cast the vote
        triage_voting::cast_vote_internal(
            vote,
            voter,
            severity_choice,
            stake_balance,
            ctx,
        );
    }

    /// Finalize a triage vote after the deadline has passed
    /// Can be called by anyone once the deadline is reached and quorum is met
    /// Determines the winning severity and processes slashing
    public entry fun finalize_triage(
        vote: &mut TriageVote,
        ctx: &mut TxContext,
    ) {
        // Finalize the vote
        triage_voting::finalize_vote_internal(vote, ctx);
    }

    /// Claim voting rewards for a majority voter
    /// Only voters who voted for the winning severity can claim
    /// Returns original stake plus proportional share of slashed minority stakes
    public entry fun claim_voting_rewards(
        vote: &mut TriageVote,
        ctx: &mut TxContext,
    ) {
        let voter = tx_context::sender(ctx);

        // Distribute the reward
        let reward_balance = triage_rewards::distribute_reward(vote, voter);

        // Store the reward amount before converting to coin
        let reward_amount = balance::value(&reward_balance);

        // Convert balance to coin and transfer to voter
        let reward_coin = coin::from_balance(reward_balance, ctx);
        transfer::public_transfer(reward_coin, voter);

        // Emit reward claimed event
        triage_events::emit_reward_claimed(
            triage_types::id(vote),
            voter,
            reward_amount,
            ctx.epoch(),
        );
    }

    // ======== View Functions ========

    /// Get the current status of a vote
    /// Returns: (status, final_severity, total_staked, voting_deadline)
    /// status: 0=ACTIVE, 1=FINALIZED, 2=CANCELLED
    /// final_severity: 0-4 (only valid if status=FINALIZED)
    public fun get_vote_status(vote: &TriageVote): (u8, u8, u64, u64) {
        let status = triage_types::status(vote);
        let final_severity = triage_types::final_severity(vote);
        let total_staked = triage_types::total_staked(vote);
        let deadline = triage_types::voting_deadline(vote);

        (status, final_severity, total_staked, deadline)
    }

    /// Get information about a specific voter's participation
    /// Returns: (severity_choice, stake_amount, claimed_reward)
    /// Returns (0, 0, false) if voter hasn't voted
    public fun get_voter_info(vote: &TriageVote, voter: address): (u8, u64, bool) {
        if (!triage_types::has_voted(vote, voter)) {
            return (0, 0, false)
        };

        let record = triage_types::get_voter_record(vote, voter);
        let severity = triage_types::vote_record_severity_choice(record);
        let stake = triage_types::vote_record_stake_amount(record);
        let claimed = triage_types::vote_record_claimed_reward(record);

        (severity, stake, claimed)
    }

    /// Check if voting is still open
    /// Returns true if the vote is active and deadline hasn't passed
    public fun can_vote(vote: &TriageVote, current_epoch: u64): bool {
        triage_voting::can_vote(vote, current_epoch)
    }

    /// Check if the vote can be finalized
    /// Returns true if deadline passed and quorum met
    public fun can_finalize(vote: &TriageVote, current_epoch: u64): bool {
        triage_voting::can_finalize(vote, current_epoch)
    }

    /// Get the distribution of stakes across all severity levels
    /// Returns vector with 5 elements: [stake_for_0, stake_for_1, ..., stake_for_4]
    public fun get_vote_distribution(vote: &TriageVote): vector<u64> {
        let mut distribution = vector::empty<u64>();

        let mut severity = triage_types::severity_none();
        while (severity <= triage_types::severity_critical()) {
            let stake = triage_types::get_severity_stake(vote, severity);
            vector::push_back(&mut distribution, stake);
            severity = severity + 1;
        };

        distribution
    }

    /// Get detailed vote metadata
    /// Returns: (report_id, program_id, creator, minimum_quorum)
    public fun get_vote_metadata(vote: &TriageVote): (ID, ID, address, u64) {
        let report_id = triage_types::report_id(vote);
        let program_id = triage_types::program_id(vote);
        let creator = triage_types::creator(vote);
        let quorum = triage_types::minimum_quorum(vote);

        (report_id, program_id, creator, quorum)
    }

    /// Get the stake amount for a specific severity level
    public fun get_severity_stake(vote: &TriageVote, severity: u8): u64 {
        triage_types::get_severity_stake(vote, severity)
    }

    /// Check if a specific address has voted
    public fun has_voted(vote: &TriageVote, voter: address): bool {
        triage_types::has_voted(vote, voter)
    }

    /// Get the reward pool value
    public fun get_reward_pool_value(vote: &TriageVote): u64 {
        triage_types::reward_pool_value(vote)
    }

    /// Check if a voter is eligible for rewards
    /// Returns true if voter voted for winning severity and hasn't claimed yet
    public fun is_eligible_for_reward(vote: &TriageVote, voter: address): bool {
        triage_rewards::is_eligible_for_reward(vote, voter)
    }

    /// Calculate the potential reward for a voter
    /// Returns the amount they would receive if they claim now
    /// Returns 0 if not eligible or already claimed
    public fun calculate_voter_reward(vote: &TriageVote, voter: address): u64 {
        if (!triage_rewards::is_eligible_for_reward(vote, voter)) {
            return 0
        };

        let voter_stake = {
            let record = triage_types::get_voter_record(vote, voter);
            triage_types::vote_record_stake_amount(record)
        };

        let reward_share = triage_rewards::calculate_reward_share(vote, voter);

        // Total payout = original stake + reward
        voter_stake + reward_share
    }

    /// Get comprehensive information about a voter's reward status
    /// Returns: (is_eligible, original_stake, reward_amount, total_payout, already_claimed)
    public fun get_voter_reward_details(
        vote: &TriageVote,
        voter: address
    ): (bool, u64, u64, u64, bool) {
        let (is_eligible, original_stake, reward_amount, claimed) =
            triage_rewards::get_voter_reward_info(vote, voter);

        let total_payout = original_stake + reward_amount;

        (is_eligible, original_stake, reward_amount, total_payout, claimed)
    }

    /// Get the vote ID from the registry for a specific report
    public fun get_vote_id_for_report(registry: &TriageRegistry, report_id: ID): ID {
        triage_types::get_vote_id_for_report(registry, report_id)
    }

    /// Check if a report has an associated vote
    public fun has_vote_for_report(registry: &TriageRegistry, report_id: ID): bool {
        triage_types::has_vote_for_report(registry, report_id)
    }

    /// Get the winning severity (only valid after finalization)
    public fun get_winning_severity(vote: &TriageVote): u8 {
        assert!(triage_types::is_finalized(vote), 999);
        triage_types::final_severity(vote)
    }

    /// Get complete vote statistics
    /// Returns: (total_staked, num_voters, reward_pool, winning_stake, minority_stake)
    public fun get_vote_statistics(vote: &TriageVote): (u64, u64, u64, u64, u64) {
        let total_staked = triage_types::total_staked(vote);
        let reward_pool = triage_types::reward_pool_value(vote);

        let (winning_stake, minority_stake) = if (triage_types::is_finalized(vote)) {
            let winning = triage_voting::get_winning_stake(vote);
            let minority = triage_voting::get_minority_stake(vote);
            (winning, minority)
        } else {
            (0, 0)
        };

        // Note: We can't easily count voters without iterating the table
        // Return 0 for num_voters as a placeholder
        (total_staked, 0, reward_pool, winning_stake, minority_stake)
    }

    // ======== Admin Functions ========

    /// Get all severity level constants
    /// Returns: (NONE, LOW, MEDIUM, HIGH, CRITICAL)
    public fun get_severity_levels(): (u8, u8, u8, u8, u8) {
        (
            triage_types::severity_none(),
            triage_types::severity_low(),
            triage_types::severity_medium(),
            triage_types::severity_high(),
            triage_types::severity_critical(),
        )
    }

    /// Get voting configuration constants
    /// Returns: (voting_period_epochs, default_minimum_quorum, slash_percentage_bp)
    public fun get_voting_config(): (u64, u64, u64) {
        (
            triage_types::voting_period_epochs(),
            triage_types::default_minimum_quorum(),
            triage_types::slash_percentage_bp(),
        )
    }

    // ======== Test-Only Functions ========

    #[test_only]
    public fun test_create_vote(
        registry: &mut TriageRegistry,
        report_id: ID,
        program_id: ID,
        minimum_quorum: u64,
        ctx: &mut TxContext,
    ) {
        create_triage_vote(registry, report_id, program_id, minimum_quorum, ctx)
    }

    #[test_only]
    public fun test_cast_vote(
        vote: &mut TriageVote,
        severity_choice: u8,
        stake_coin: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        cast_vote(vote, severity_choice, stake_coin, ctx)
    }

    #[test_only]
    /// Create vote with custom deadline for testing (to avoid gas exhaustion)
    public entry fun create_triage_vote_with_deadline(
        registry: &mut TriageRegistry,
        report_id: ID,
        program_id: ID,
        minimum_quorum: u64,
        voting_period: u64,
        ctx: &mut TxContext,
    ) {
        assert!(minimum_quorum >= 1_000_000_000, E_INVALID_QUORUM);

        let creator = tx_context::sender(ctx);
        let current_epoch = tx_context::epoch(ctx);

        // Create vote with custom deadline
        let vote = triage_types::new_with_custom_deadline(
            report_id,
            program_id,
            creator,
            current_epoch,
            minimum_quorum,
            voting_period,
            ctx,
        );

        let vote_id = triage_types::id(&vote);

        // Register in the registry
        triage_types::register_vote(registry, report_id, vote_id);

        // Share the vote object so anyone can vote
        transfer::public_share_object(vote);
    }
}
