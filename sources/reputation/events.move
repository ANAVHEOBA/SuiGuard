// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Reputation System Events
module suiguard::reputation_events {
    use sui::object::ID;
    use sui::event;

    /// Emitted when a researcher profile is created
    public struct ProfileCreated has copy, drop {
        profile_id: ID,
        researcher: address,
        created_at: u64,
    }

    /// Emitted when reputation is updated
    public struct ReputationUpdated has copy, drop {
        profile_id: ID,
        researcher: address,
        old_score: u64,
        new_score: u64,
        old_tier: u8,
        new_tier: u8,
        updated_at: u64,
    }

    /// Emitted when earnings are added
    public struct EarningsAdded has copy, drop {
        profile_id: ID,
        researcher: address,
        amount: u64,
        new_total_earnings: u64,
        added_at: u64,
    }

    /// Emitted when an achievement is earned
    public struct AchievementEarned has copy, drop {
        badge_id: ID,
        profile_id: ID,
        researcher: address,
        achievement_type: u8,
        name: vector<u8>,
        earned_at: u64,
    }

    // ========== Event Emission Functions ==========

    public(package) fun emit_profile_created(
        profile_id: ID,
        researcher: address,
        created_at: u64,
    ) {
        event::emit(ProfileCreated {
            profile_id,
            researcher,
            created_at,
        });
    }

    public(package) fun emit_reputation_updated(
        profile_id: ID,
        researcher: address,
        old_score: u64,
        new_score: u64,
        old_tier: u8,
        new_tier: u8,
        updated_at: u64,
    ) {
        event::emit(ReputationUpdated {
            profile_id,
            researcher,
            old_score,
            new_score,
            old_tier,
            new_tier,
            updated_at,
        });
    }

    public(package) fun emit_earnings_added(
        profile_id: ID,
        researcher: address,
        amount: u64,
        new_total_earnings: u64,
        added_at: u64,
    ) {
        event::emit(EarningsAdded {
            profile_id,
            researcher,
            amount,
            new_total_earnings,
            added_at,
        });
    }

    public(package) fun emit_achievement_earned(
        badge_id: ID,
        profile_id: ID,
        researcher: address,
        achievement_type: u8,
        name: vector<u8>,
        earned_at: u64,
    ) {
        event::emit(AchievementEarned {
            badge_id,
            profile_id,
            researcher,
            achievement_type,
            name,
            earned_at,
        });
    }
}
