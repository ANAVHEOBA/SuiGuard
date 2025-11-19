// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Reward calculation and distribution logic for triage voting.
/// This module handles slashing of minority stakes and proportional
/// distribution of rewards to majority voters.
module suiguard::triage_rewards {
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;

    use suiguard::triage_types::{Self, TriageVote};

    // ======== Error Codes ========

    const E_VOTE_NOT_FINALIZED: u64 = 200;
    const E_NOT_MAJORITY_VOTER: u64 = 201;
    const E_ALREADY_CLAIMED: u64 = 202;
    const E_INSUFFICIENT_REWARD_POOL: u64 = 203;
    const E_NOT_VOTED: u64 = 204;

    // ======== Slashing Calculations ========

    /// Calculate the total amount to be slashed from minority voters
    /// Returns 10% of all minority stakes
    public(package) fun calculate_slash_amount(vote: &TriageVote): u64 {
        assert!(triage_types::is_finalized(vote), E_VOTE_NOT_FINALIZED);

        let final_severity = triage_types::final_severity(vote);
        let winning_stake = triage_types::get_severity_stake(vote, final_severity);
        let total_staked = triage_types::total_staked(vote);

        // Calculate minority stake (everyone who didn't vote for winner)
        let minority_stake = total_staked - winning_stake;

        // Slash 10% (1000 basis points)
        // Use u128 to prevent overflow
        let slash_amount = (((minority_stake as u128) * (triage_types::slash_percentage_bp() as u128)) /
                          (triage_types::basis_points_max() as u128) as u64);

        slash_amount
    }

    /// Calculate a specific voter's share of the reward pool
    /// Returns the proportional amount based on their stake in the winning choice
    public(package) fun calculate_reward_share(
        vote: &TriageVote,
        voter: address,
    ): u64 {
        assert!(triage_types::is_finalized(vote), E_VOTE_NOT_FINALIZED);
        assert!(triage_types::has_voted(vote, voter), E_NOT_VOTED);

        let voter_record = triage_types::get_voter_record(vote, voter);
        let voter_choice = triage_types::vote_record_severity_choice(voter_record);
        let final_severity = triage_types::final_severity(vote);

        // Must be a majority voter
        assert!(voter_choice == final_severity, E_NOT_MAJORITY_VOTER);

        let voter_stake = triage_types::vote_record_stake_amount(voter_record);
        let winning_total_stake = triage_types::get_severity_stake(vote, final_severity);

        // Calculate total reward pool (slashed amount from minority)
        let slash_amount = calculate_slash_amount(vote);

        // Calculate proportional share: (voter_stake / winning_total_stake) * slash_amount
        // Use u128 to prevent overflow when multiplying large u64 values
        let reward_share = (((voter_stake as u128) * (slash_amount as u128)) / (winning_total_stake as u128) as u64);

        reward_share
    }

    // ======== Reward Distribution ========

    /// Process slashing logic conceptually
    /// In practice, all stakes are already in the reward pool
    /// This function calculates what portion should be distributed vs returned
    public(package) fun process_slashing(vote: &TriageVote): (u64, u64) {
        assert!(triage_types::is_finalized(vote), E_VOTE_NOT_FINALIZED);

        let final_severity = triage_types::final_severity(vote);
        let winning_stake = triage_types::get_severity_stake(vote, final_severity);
        let total_staked = triage_types::total_staked(vote);
        let minority_stake = total_staked - winning_stake;

        // Amount slashed from minority (10%)
        // Use u128 to prevent overflow
        let slashed_amount = (((minority_stake as u128) * (triage_types::slash_percentage_bp() as u128)) /
                            (triage_types::basis_points_max() as u128) as u64);

        // Amount returned to minority (90% of their stake)
        let returned_to_minority = minority_stake - slashed_amount;

        (slashed_amount, returned_to_minority)
    }

    /// Distribute reward to a specific voter
    /// Returns the total payout (original stake + reward share)
    /// Marks the voter as having claimed their reward
    public(package) fun distribute_reward(
        vote: &mut TriageVote,
        voter: address,
    ): Balance<SUI> {
        assert!(triage_types::is_finalized(vote), E_VOTE_NOT_FINALIZED);
        assert!(triage_types::has_voted(vote, voter), E_NOT_VOTED);

        let voter_record = triage_types::get_voter_record(vote, voter);

        // Check not already claimed
        assert!(
            !triage_types::vote_record_claimed_reward(voter_record),
            E_ALREADY_CLAIMED
        );

        let voter_choice = triage_types::vote_record_severity_choice(voter_record);
        let final_severity = triage_types::final_severity(vote);

        // Must be majority voter
        assert!(voter_choice == final_severity, E_NOT_MAJORITY_VOTER);

        let voter_stake = triage_types::vote_record_stake_amount(voter_record);

        // Calculate reward share
        let reward_share = calculate_reward_share(vote, voter);

        // Total payout = original stake + reward from slashing
        let total_payout = voter_stake + reward_share;

        // Mark as claimed
        triage_types::mark_reward_claimed(vote, voter);

        // Take from reward pool
        assert!(
            triage_types::reward_pool_value(vote) >= total_payout,
            E_INSUFFICIENT_REWARD_POOL
        );

        triage_types::take_from_reward_pool(vote, total_payout)
    }

    // ======== Helper Functions ========

    /// Check if a voter is eligible for rewards
    public(package) fun is_eligible_for_reward(vote: &TriageVote, voter: address): bool {
        // Vote must be finalized
        if (!triage_types::is_finalized(vote)) {
            return false
        };

        // Voter must have voted
        if (!triage_types::has_voted(vote, voter)) {
            return false
        };

        let voter_record = triage_types::get_voter_record(vote, voter);

        // Must not have claimed already
        if (triage_types::vote_record_claimed_reward(voter_record)) {
            return false
        };

        // Must have voted for winning severity
        let voter_choice = triage_types::vote_record_severity_choice(voter_record);
        let final_severity = triage_types::final_severity(vote);

        voter_choice == final_severity
    }

    /// Check if a voter is in the majority
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

    /// Calculate how much a minority voter gets back (90% of their stake)
    public(package) fun calculate_minority_return(
        vote: &TriageVote,
        voter: address,
    ): u64 {
        assert!(triage_types::is_finalized(vote), E_VOTE_NOT_FINALIZED);
        assert!(triage_types::has_voted(vote, voter), E_NOT_VOTED);

        let voter_record = triage_types::get_voter_record(vote, voter);
        let voter_choice = triage_types::vote_record_severity_choice(voter_record);
        let final_severity = triage_types::final_severity(vote);

        // Only for minority voters
        if (voter_choice == final_severity) {
            return 0
        };

        let voter_stake = triage_types::vote_record_stake_amount(voter_record);

        // Return 90% (keep 10% slashed)
        let return_percentage = triage_types::basis_points_max() - triage_types::slash_percentage_bp();
        // Use u128 to prevent overflow
        let return_amount = (((voter_stake as u128) * (return_percentage as u128)) / (triage_types::basis_points_max() as u128) as u64);

        return_amount
    }

    /// Get the total reward pool available for distribution
    public(package) fun get_reward_pool_balance(vote: &TriageVote): u64 {
        triage_types::reward_pool_value(vote)
    }

    // ======== View Functions ========

    /// Get comprehensive reward information for a voter
    /// Returns: (is_eligible, original_stake, reward_amount, already_claimed)
    public fun get_voter_reward_info(vote: &TriageVote, voter: address): (bool, u64, u64, bool) {
        if (!triage_types::has_voted(vote, voter)) {
            return (false, 0, 0, false)
        };

        let voter_record = triage_types::get_voter_record(vote, voter);
        let voter_stake = triage_types::vote_record_stake_amount(voter_record);
        let claimed = triage_types::vote_record_claimed_reward(voter_record);

        if (!triage_types::is_finalized(vote)) {
            return (false, voter_stake, 0, claimed)
        };

        let is_eligible = is_eligible_for_reward(vote, voter);
        let reward_amount = if (is_eligible && !claimed) {
            calculate_reward_share(vote, voter)
        } else {
            0
        };

        (is_eligible, voter_stake, reward_amount, claimed)
    }

    // ======== Test-Only Functions ========

    #[test_only]
    public fun test_calculate_slash_amount(vote: &TriageVote): u64 {
        calculate_slash_amount(vote)
    }

    #[test_only]
    public fun test_calculate_reward_share(vote: &TriageVote, voter: address): u64 {
        calculate_reward_share(vote, voter)
    }

    #[test_only]
    public fun test_distribute_reward(vote: &mut TriageVote, voter: address): Balance<SUI> {
        distribute_reward(vote, voter)
    }
}
