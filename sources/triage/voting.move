// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Core voting logic for the DAO-based severity triage system.
/// This module contains package-only functions for vote creation, casting,
/// validation, and finalization.
module suiguard::triage_voting {
    use sui::object::ID;
    use sui::tx_context::TxContext;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::vec_map;

    use suiguard::triage_types::{Self, TriageVote, TriageRegistry};
    use suiguard::triage_events;

    // ======== Error Codes ========

    const E_VOTING_ENDED: u64 = 100;
    const E_VOTING_NOT_ENDED: u64 = 101;
    const E_QUORUM_NOT_MET: u64 = 102;
    const E_ALREADY_VOTED: u64 = 103;
    const E_INVALID_SEVERITY: u64 = 104;
    const E_VOTE_NOT_ACTIVE: u64 = 105;
    const E_VOTE_ALREADY_FINALIZED: u64 = 106;

    // ======== Vote Creation ========

    /// Create a new triage vote
    /// Returns the created TriageVote object
    public(package) fun create_vote(
        report_id: ID,
        program_id: ID,
        creator: address,
        minimum_quorum: u64,
        ctx: &mut TxContext,
    ): TriageVote {
        let current_epoch = ctx.epoch();

        let vote = triage_types::new_triage_vote(
            report_id,
            program_id,
            creator,
            current_epoch,
            minimum_quorum,
            ctx,
        );

        // Emit creation event
        triage_events::emit_vote_created(
            triage_types::id(&vote),
            report_id,
            program_id,
            creator,
            triage_types::voting_deadline(&vote),
            minimum_quorum,
        );

        vote
    }

    /// Create a new urgent/expedited triage vote
    /// Returns the created TriageVote object with 6-hour deadline
    public(package) fun create_urgent_vote(
        report_id: ID,
        program_id: ID,
        creator: address,
        premium: Balance<SUI>,
        ctx: &mut TxContext,
    ): TriageVote {
        let current_epoch = ctx.epoch();

        let vote = triage_types::new_urgent_triage_vote(
            report_id,
            program_id,
            creator,
            current_epoch,
            premium,
            ctx,
        );

        // Emit creation event
        triage_events::emit_vote_created(
            triage_types::id(&vote),
            report_id,
            program_id,
            creator,
            triage_types::voting_deadline(&vote),
            triage_types::minimum_quorum(&vote),
        );

        vote
    }

    // ======== Vote Casting ========

    /// Internal function to cast a vote
    /// Validates voter hasn't voted, deadline not passed, and severity is valid
    public(package) fun cast_vote_internal(
        vote: &mut TriageVote,
        voter: address,
        severity_choice: u8,
        stake: Balance<SUI>,
        ctx: &TxContext,
    ) {
        let current_epoch = ctx.epoch();

        // Validate vote is active
        assert!(triage_types::is_active(vote), E_VOTE_NOT_ACTIVE);

        // Validate deadline not passed
        assert!(current_epoch <= triage_types::voting_deadline(vote), E_VOTING_ENDED);

        // Validate voter hasn't voted yet
        assert!(!triage_types::has_voted(vote, voter), E_ALREADY_VOTED);

        // Validate severity choice is valid (0-4)
        assert!(severity_choice <= triage_types::severity_critical(), E_INVALID_SEVERITY);

        let stake_amount = balance::value(&stake);

        // Add voter record
        triage_types::add_voter(vote, voter, severity_choice, stake_amount, current_epoch);

        // Update vote distribution for chosen severity
        triage_types::add_to_severity_stake(vote, severity_choice, stake_amount);

        // Update total staked
        triage_types::add_to_total_staked(vote, stake_amount);

        // Add stake to reward pool (will be distributed later)
        triage_types::add_to_reward_pool(vote, stake);

        // Emit vote cast event
        triage_events::emit_vote_cast(
            triage_types::id(vote),
            voter,
            severity_choice,
            stake_amount,
            current_epoch,
        );
    }

    // ======== Validation Functions ========

    /// Check if the vote can be finalized
    /// Returns true if quorum is met AND deadline has passed
    public(package) fun can_finalize(vote: &TriageVote, current_epoch: u64): bool {
        // Must be active
        if (!triage_types::is_active(vote)) {
            return false
        };

        // Deadline must have passed
        if (current_epoch <= triage_types::voting_deadline(vote)) {
            return false
        };

        // Quorum must be met
        if (triage_types::total_staked(vote) < triage_types::minimum_quorum(vote)) {
            return false
        };

        true
    }

    /// Check if voting is still open
    public(package) fun can_vote(vote: &TriageVote, current_epoch: u64): bool {
        triage_types::is_active(vote) &&
        current_epoch <= triage_types::voting_deadline(vote)
    }

    // ======== Severity Calculation ========

    /// Calculate the winning severity (severity with most stake)
    /// Returns the severity level (0-4) with the highest total stake
    public(package) fun calculate_winning_severity(vote: &TriageVote): u8 {
        let mut max_stake = 0u64;
        let mut winning_severity = triage_types::severity_none();

        // Check each severity level
        let mut severity = triage_types::severity_none();
        while (severity <= triage_types::severity_critical()) {
            let stake = triage_types::get_severity_stake(vote, severity);
            if (stake > max_stake) {
                max_stake = stake;
                winning_severity = severity;
            };
            severity = severity + 1;
        };

        winning_severity
    }

    // ======== Vote Finalization ========

    /// Finalize the vote - determine winner and calculate slashing
    /// This function:
    /// 1. Validates the vote can be finalized
    /// 2. Calculates the winning severity
    /// 3. Processes slashing of minority stakes
    /// 4. Sets the final severity and status
    public(package) fun finalize_vote_internal(
        vote: &mut TriageVote,
        ctx: &TxContext,
    ) {
        let current_epoch = ctx.epoch();

        // Validate vote can be finalized
        assert!(triage_types::is_active(vote), E_VOTE_ALREADY_FINALIZED);
        assert!(current_epoch > triage_types::voting_deadline(vote), E_VOTING_NOT_ENDED);
        assert!(
            triage_types::total_staked(vote) >= triage_types::minimum_quorum(vote),
            E_QUORUM_NOT_MET
        );

        // Calculate winning severity
        let winning_severity = calculate_winning_severity(vote);

        // Set final severity
        triage_types::set_final_severity(vote, winning_severity);

        // Mark as finalized
        triage_types::set_status(vote, triage_types::status_finalized());

        // Emit finalization event
        triage_events::emit_triage_finalized(
            triage_types::id(vote),
            triage_types::report_id(vote),
            winning_severity,
            triage_types::total_staked(vote),
            triage_types::reward_pool_value(vote),
            current_epoch,
        );
    }

    // ======== Reward Calculation ========

    /// Calculate the reward amount for a specific voter
    /// Returns 0 if:
    /// - Vote not finalized
    /// - Voter didn't vote for winning severity
    /// - Voter already claimed
    /// Otherwise returns their proportional share of the reward pool
    public(package) fun calculate_voter_reward(
        vote: &TriageVote,
        voter: address,
    ): u64 {
        // Vote must be finalized
        if (!triage_types::is_finalized(vote)) {
            return 0
        };

        // Voter must have voted
        if (!triage_types::has_voted(vote, voter)) {
            return 0
        };

        let voter_record = triage_types::get_voter_record(vote, voter);

        // Voter must not have claimed already
        if (triage_types::vote_record_claimed_reward(voter_record)) {
            return 0
        };

        let voter_choice = triage_types::vote_record_severity_choice(voter_record);
        let final_severity = triage_types::final_severity(vote);

        // Voter must have voted for winning severity
        if (voter_choice != final_severity) {
            return 0
        };

        let voter_stake = triage_types::vote_record_stake_amount(voter_record);
        let winning_total_stake = triage_types::get_severity_stake(vote, final_severity);
        let total_staked = triage_types::total_staked(vote);

        // Calculate slashed amount (10% of minority stakes)
        let minority_stake = total_staked - winning_total_stake;
        let slash_amount = (minority_stake * triage_types::slash_percentage_bp()) /
                          triage_types::basis_points_max();

        // Calculate voter's proportional share of slashed funds
        // reward = (voter_stake / winning_total_stake) * slash_amount
        let reward = (voter_stake * slash_amount) / winning_total_stake;

        // Add back their original stake
        voter_stake + reward
    }

    // ======== Helper Functions ========

    /// Check if a voter is part of the majority (voted for winning severity)
    public(package) fun is_majority_voter(vote: &TriageVote, voter: address): bool {
        if (!triage_types::is_finalized(vote)) {
            return false
        };

        if (!triage_types::has_voted(vote, voter)) {
            return false
        };

        let voter_record = triage_types::get_voter_record(vote, voter);
        let voter_choice = triage_types::vote_record_severity_choice(voter_record);

        voter_choice == triage_types::final_severity(vote)
    }

    /// Get the total stake for the winning severity
    public(package) fun get_winning_stake(vote: &TriageVote): u64 {
        assert!(triage_types::is_finalized(vote), E_VOTE_NOT_ACTIVE);
        let final_severity = triage_types::final_severity(vote);
        triage_types::get_severity_stake(vote, final_severity)
    }

    /// Get the total stake for losing severities (minority)
    public(package) fun get_minority_stake(vote: &TriageVote): u64 {
        assert!(triage_types::is_finalized(vote), E_VOTE_NOT_ACTIVE);
        triage_types::total_staked(vote) - get_winning_stake(vote)
    }

    // ======== Test-Only Functions ========

    #[test_only]
    public fun test_create_vote(
        report_id: ID,
        program_id: ID,
        creator: address,
        minimum_quorum: u64,
        ctx: &mut TxContext,
    ): TriageVote {
        create_vote(report_id, program_id, creator, minimum_quorum, ctx)
    }

    #[test_only]
    public fun test_cast_vote(
        vote: &mut TriageVote,
        voter: address,
        severity_choice: u8,
        stake: Balance<SUI>,
        ctx: &TxContext,
    ) {
        cast_vote_internal(vote, voter, severity_choice, stake, ctx)
    }

    #[test_only]
    public fun test_finalize_vote(vote: &mut TriageVote, ctx: &TxContext) {
        finalize_vote_internal(vote, ctx)
    }
}
