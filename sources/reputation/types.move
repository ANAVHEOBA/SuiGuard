// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Reputation System Types
/// Tracks researcher statistics and achievements
module suiguard::reputation_types {
    use std::option::{Self, Option};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::TxContext;
    use sui::vec_set::{Self, VecSet};

    /// Researcher reputation profile
    /// Tracks bug reports by severity and earnings
    public struct ResearcherProfile has key, store {
        id: UID,
        /// Address of the researcher
        researcher: address,
        /// Total bugs found by severity
        critical_bugs: u64,
        high_bugs: u64,
        medium_bugs: u64,
        low_bugs: u64,
        informational_bugs: u64,
        /// Total SUI earned from bounties (in MIST)
        total_earnings: u64,
        /// Current reputation score
        reputation_score: u64,
        /// Reputation tier (0-5: Newbie, Bronze, Silver, Gold, Platinum, Legend)
        tier: u8,
        /// Achievement badge IDs earned
        achievements: VecSet<ID>,
        /// When profile was created
        created_at: u64,
        /// Last updated timestamp
        updated_at: u64,
    }

    /// Achievement badge NFT (soulbound)
    /// Non-transferable badge for milestones
    public struct AchievementBadge has key {
        id: UID,
        /// Owner of the badge
        owner: address,
        /// Achievement type (see constants below)
        achievement_type: u8,
        /// Badge name
        name: vector<u8>,
        /// Badge description
        description: vector<u8>,
        /// Badge image URL (stored on Walrus)
        image_url: vector<u8>,
        /// When the badge was earned
        earned_at: u64,
    }

    /// Achievement types
    const ACHIEVEMENT_FIRST_BLOOD: u8 = 0;        // First bug found
    const ACHIEVEMENT_CRITICAL_HUNTER: u8 = 1;    // 5 critical bugs
    const ACHIEVEMENT_HIGH_ROLLER: u8 = 2;         // 10 high severity bugs
    const ACHIEVEMENT_MILLIONAIRE: u8 = 3;         // 1M SUI earned
    const ACHIEVEMENT_REENTRANCY_EXPERT: u8 = 4;  // 10 reentrancy bugs
    const ACHIEVEMENT_OVERFLOW_MASTER: u8 = 5;    // 10 overflow bugs
    const ACHIEVEMENT_LOGIC_GURU: u8 = 6;         // 10 logic error bugs
    const ACHIEVEMENT_ACCESS_SPECIALIST: u8 = 7;  // 10 access control bugs
    const ACHIEVEMENT_PRICE_ORACLE_HUNTER: u8 = 8; // 10 price manipulation bugs
    const ACHIEVEMENT_PROLIFIC: u8 = 9;           // 50 total bugs
    const ACHIEVEMENT_LEGEND: u8 = 10;            // 100 total bugs

    /// Reputation tiers
    const TIER_NEWBIE: u8 = 0;     // 0-999 score
    const TIER_BRONZE: u8 = 1;     // 1000-4999 score
    const TIER_SILVER: u8 = 2;     // 5000-19999 score
    const TIER_GOLD: u8 = 3;       // 20000-49999 score
    const TIER_PLATINUM: u8 = 4;   // 50000-99999 score
    const TIER_LEGEND: u8 = 5;     // 100000+ score

    /// Reputation score weights
    const SCORE_CRITICAL: u64 = 1000;
    const SCORE_HIGH: u64 = 500;
    const SCORE_MEDIUM: u64 = 100;
    const SCORE_LOW: u64 = 10;

    /// Tier bonus multipliers (in basis points, 10000 = 1.0x)
    const BONUS_NEWBIE: u64 = 10000;      // 1.0x
    const BONUS_BRONZE: u64 = 10250;      // 1.025x
    const BONUS_SILVER: u64 = 10500;      // 1.05x
    const BONUS_GOLD: u64 = 10750;        // 1.075x
    const BONUS_PLATINUM: u64 = 11000;    // 1.1x
    const BONUS_LEGEND: u64 = 11500;      // 1.15x

    const BASIS_POINTS_MAX: u64 = 10000;

    // ========== Constructor Functions ==========

    /// Create a new researcher profile
    public(package) fun new_profile(
        researcher: address,
        created_at: u64,
        ctx: &mut TxContext,
    ): ResearcherProfile {
        ResearcherProfile {
            id: object::new(ctx),
            researcher,
            critical_bugs: 0,
            high_bugs: 0,
            medium_bugs: 0,
            low_bugs: 0,
            informational_bugs: 0,
            total_earnings: 0,
            reputation_score: 0,
            tier: TIER_NEWBIE,
            achievements: vec_set::empty(),
            created_at,
            updated_at: created_at,
        }
    }

    /// Create a new achievement badge
    public(package) fun new_achievement_badge(
        owner: address,
        achievement_type: u8,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        earned_at: u64,
        ctx: &mut TxContext,
    ): AchievementBadge {
        AchievementBadge {
            id: object::new(ctx),
            owner,
            achievement_type,
            name,
            description,
            image_url,
            earned_at,
        }
    }

    // ========== Getters ==========

    public fun id(profile: &ResearcherProfile): &UID {
        &profile.id
    }

    public fun researcher(profile: &ResearcherProfile): address {
        profile.researcher
    }

    public fun critical_bugs(profile: &ResearcherProfile): u64 {
        profile.critical_bugs
    }

    public fun high_bugs(profile: &ResearcherProfile): u64 {
        profile.high_bugs
    }

    public fun medium_bugs(profile: &ResearcherProfile): u64 {
        profile.medium_bugs
    }

    public fun low_bugs(profile: &ResearcherProfile): u64 {
        profile.low_bugs
    }

    public fun informational_bugs(profile: &ResearcherProfile): u64 {
        profile.informational_bugs
    }

    public fun total_earnings(profile: &ResearcherProfile): u64 {
        profile.total_earnings
    }

    public fun reputation_score(profile: &ResearcherProfile): u64 {
        profile.reputation_score
    }

    public fun tier(profile: &ResearcherProfile): u8 {
        profile.tier
    }

    public fun achievements(profile: &ResearcherProfile): &VecSet<ID> {
        &profile.achievements
    }

    public fun created_at(profile: &ResearcherProfile): u64 {
        profile.created_at
    }

    public fun updated_at(profile: &ResearcherProfile): u64 {
        profile.updated_at
    }

    // === Achievement Badge Getters ===

    public fun badge_id(badge: &AchievementBadge): &UID {
        &badge.id
    }

    public fun badge_owner(badge: &AchievementBadge): address {
        badge.owner
    }

    public fun badge_type(badge: &AchievementBadge): u8 {
        badge.achievement_type
    }

    public fun badge_name(badge: &AchievementBadge): &vector<u8> {
        &badge.name
    }

    public fun badge_description(badge: &AchievementBadge): &vector<u8> {
        &badge.description
    }

    public fun badge_image_url(badge: &AchievementBadge): &vector<u8> {
        &badge.image_url
    }

    public fun badge_earned_at(badge: &AchievementBadge): u64 {
        badge.earned_at
    }

    // ========== Helper Functions ==========

    /// Calculate total bugs found
    public fun total_bugs(profile: &ResearcherProfile): u64 {
        profile.critical_bugs +
        profile.high_bugs +
        profile.medium_bugs +
        profile.low_bugs +
        profile.informational_bugs
    }

    /// Calculate reputation score based on bug severity counts
    public fun calculate_score(
        critical: u64,
        high: u64,
        medium: u64,
        low: u64,
    ): u64 {
        (critical * SCORE_CRITICAL) +
        (high * SCORE_HIGH) +
        (medium * SCORE_MEDIUM) +
        (low * SCORE_LOW)
    }

    /// Determine tier based on reputation score
    public fun calculate_tier(score: u64): u8 {
        if (score >= 100000) {
            TIER_LEGEND
        } else if (score >= 50000) {
            TIER_PLATINUM
        } else if (score >= 20000) {
            TIER_GOLD
        } else if (score >= 5000) {
            TIER_SILVER
        } else if (score >= 1000) {
            TIER_BRONZE
        } else {
            TIER_NEWBIE
        }
    }

    /// Get bonus multiplier for a tier (in basis points)
    public fun get_tier_bonus(tier: u8): u64 {
        if (tier == TIER_LEGEND) {
            BONUS_LEGEND
        } else if (tier == TIER_PLATINUM) {
            BONUS_PLATINUM
        } else if (tier == TIER_GOLD) {
            BONUS_GOLD
        } else if (tier == TIER_SILVER) {
            BONUS_SILVER
        } else if (tier == TIER_BRONZE) {
            BONUS_BRONZE
        } else {
            BONUS_NEWBIE
        }
    }

    /// Apply reputation bonus to payout amount
    public fun apply_bonus(base_amount: u64, tier: u8): u64 {
        let bonus_bp = get_tier_bonus(tier);
        (base_amount * bonus_bp) / BASIS_POINTS_MAX
    }

    /// Check if achievement already earned
    public fun has_achievement(profile: &ResearcherProfile, achievement_id: ID): bool {
        vec_set::contains(&profile.achievements, &achievement_id)
    }

    // ========== Mutable Functions (package-only) ==========

    /// Update bug count for a severity level
    public(package) fun increment_bug_count(
        profile: &mut ResearcherProfile,
        severity: u8,
        timestamp: u64,
    ) {
        if (severity == 0) {
            profile.critical_bugs = profile.critical_bugs + 1;
        } else if (severity == 1) {
            profile.high_bugs = profile.high_bugs + 1;
        } else if (severity == 2) {
            profile.medium_bugs = profile.medium_bugs + 1;
        } else if (severity == 3) {
            profile.low_bugs = profile.low_bugs + 1;
        } else {
            profile.informational_bugs = profile.informational_bugs + 1;
        };

        // Recalculate score and tier
        let new_score = calculate_score(
            profile.critical_bugs,
            profile.high_bugs,
            profile.medium_bugs,
            profile.low_bugs,
        );
        profile.reputation_score = new_score;
        profile.tier = calculate_tier(new_score);
        profile.updated_at = timestamp;
    }

    /// Add earnings to profile
    public(package) fun add_earnings(
        profile: &mut ResearcherProfile,
        amount: u64,
        timestamp: u64,
    ) {
        profile.total_earnings = profile.total_earnings + amount;
        profile.updated_at = timestamp;
    }

    /// Add achievement to profile
    public(package) fun add_achievement(
        profile: &mut ResearcherProfile,
        achievement_id: ID,
    ) {
        vec_set::insert(&mut profile.achievements, achievement_id);
    }

    // ========== Constants ==========

    public fun achievement_first_blood(): u8 { ACHIEVEMENT_FIRST_BLOOD }
    public fun achievement_critical_hunter(): u8 { ACHIEVEMENT_CRITICAL_HUNTER }
    public fun achievement_high_roller(): u8 { ACHIEVEMENT_HIGH_ROLLER }
    public fun achievement_millionaire(): u8 { ACHIEVEMENT_MILLIONAIRE }
    public fun achievement_reentrancy_expert(): u8 { ACHIEVEMENT_REENTRANCY_EXPERT }
    public fun achievement_overflow_master(): u8 { ACHIEVEMENT_OVERFLOW_MASTER }
    public fun achievement_logic_guru(): u8 { ACHIEVEMENT_LOGIC_GURU }
    public fun achievement_access_specialist(): u8 { ACHIEVEMENT_ACCESS_SPECIALIST }
    public fun achievement_price_oracle_hunter(): u8 { ACHIEVEMENT_PRICE_ORACLE_HUNTER }
    public fun achievement_prolific(): u8 { ACHIEVEMENT_PROLIFIC }
    public fun achievement_legend(): u8 { ACHIEVEMENT_LEGEND }

    public fun tier_newbie(): u8 { TIER_NEWBIE }
    public fun tier_bronze(): u8 { TIER_BRONZE }
    public fun tier_silver(): u8 { TIER_SILVER }
    public fun tier_gold(): u8 { TIER_GOLD }
    public fun tier_platinum(): u8 { TIER_PLATINUM }
    public fun tier_legend(): u8 { TIER_LEGEND }

    public fun basis_points_max(): u64 { BASIS_POINTS_MAX }

    // ========== Transfer Functions ==========

    /// Transfer achievement badge to owner (soulbound)
    /// Must be called from within package to enforce soulbound nature
    public(package) fun transfer_badge(badge: AchievementBadge, recipient: address) {
        use sui::transfer;
        transfer::transfer(badge, recipient);
    }
}
