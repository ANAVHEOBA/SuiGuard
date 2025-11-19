// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Reputation and Achievement System API
module suiguard::reputation_api {
    use sui::object::{Self, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    use suiguard::reputation_types::{Self, ResearcherProfile, AchievementBadge};
    use suiguard::reputation_events;
    use suiguard::report_types::{Self, BugReport};

    // ======== Error Codes ========

    const E_NOT_OWNER: u64 = 8000;
    const E_ALREADY_EARNED: u64 = 8001;
    const E_NOT_ELIGIBLE: u64 = 8002;

    // ======== Entry Functions ========

    /// Create a new researcher profile
    public entry fun create_profile(ctx: &mut TxContext) {
        let researcher = tx_context::sender(ctx);
        let timestamp = tx_context::epoch(ctx);

        let profile = reputation_types::new_profile(researcher, timestamp, ctx);
        let profile_id = object::uid_to_inner(reputation_types::id(&profile));

        // Emit event
        reputation_events::emit_profile_created(profile_id, researcher, timestamp);

        // Transfer profile to researcher
        transfer::public_transfer(profile, researcher);
    }

    /// Update reputation after a bug is accepted
    /// Called automatically when a payout is executed
    public fun update_reputation(
        profile: &mut ResearcherProfile,
        report: &BugReport,
        ctx: &TxContext,
    ) {
        // Verify profile owner matches researcher
        let researcher = reputation_types::researcher(profile);
        assert!(researcher == report_types::researcher(report), E_NOT_OWNER);

        let old_score = reputation_types::reputation_score(profile);
        let old_tier = reputation_types::tier(profile);

        let severity = report_types::severity(report);
        let timestamp = tx_context::epoch(ctx);

        // Increment bug count for this severity
        reputation_types::increment_bug_count(profile, severity, timestamp);

        let new_score = reputation_types::reputation_score(profile);
        let new_tier = reputation_types::tier(profile);

        // Emit event
        reputation_events::emit_reputation_updated(
            object::uid_to_inner(reputation_types::id(profile)),
            researcher,
            old_score,
            new_score,
            old_tier,
            new_tier,
            timestamp,
        );
    }

    /// Add earnings to profile
    public fun add_earnings(
        profile: &mut ResearcherProfile,
        amount: u64,
        ctx: &TxContext,
    ) {
        let timestamp = tx_context::epoch(ctx);
        reputation_types::add_earnings(profile, amount, timestamp);

        let researcher = reputation_types::researcher(profile);
        let new_total = reputation_types::total_earnings(profile);

        // Emit event
        reputation_events::emit_earnings_added(
            object::uid_to_inner(reputation_types::id(profile)),
            researcher,
            amount,
            new_total,
            timestamp,
        );
    }

    /// Mint an achievement badge
    public entry fun mint_achievement(
        profile: &mut ResearcherProfile,
        achievement_type: u8,
        ctx: &mut TxContext,
    ) {
        let researcher = tx_context::sender(ctx);
        assert!(researcher == reputation_types::researcher(profile), E_NOT_OWNER);

        // Check eligibility
        assert!(check_achievement_eligibility(profile, achievement_type), E_NOT_ELIGIBLE);

        let timestamp = tx_context::epoch(ctx);

        // Get achievement details
        let (name, description, image_url) = get_achievement_metadata(achievement_type);

        // Create badge
        let badge = reputation_types::new_achievement_badge(
            researcher,
            achievement_type,
            name,
            description,
            image_url,
            timestamp,
            ctx,
        );

        let badge_id = object::uid_to_inner(reputation_types::badge_id(&badge));

        // Add to profile
        reputation_types::add_achievement(profile, badge_id);

        // Emit event
        reputation_events::emit_achievement_earned(
            badge_id,
            object::uid_to_inner(reputation_types::id(profile)),
            researcher,
            achievement_type,
            name,
            timestamp,
        );

        // Transfer badge to researcher (soulbound - can't be sold/transferred later)
        reputation_types::transfer_badge(badge, researcher);
    }

    // ======== View Functions ========

    /// Get complete researcher statistics
    /// Returns (critical, high, medium, low, total_bugs, total_earnings, score, tier)
    public fun get_researcher_stats(profile: &ResearcherProfile): (u64, u64, u64, u64, u64, u64, u64, u8) {
        let critical = reputation_types::critical_bugs(profile);
        let high = reputation_types::high_bugs(profile);
        let medium = reputation_types::medium_bugs(profile);
        let low = reputation_types::low_bugs(profile);
        let total = reputation_types::total_bugs(profile);
        let earnings = reputation_types::total_earnings(profile);
        let score = reputation_types::reputation_score(profile);
        let tier = reputation_types::tier(profile);

        (critical, high, medium, low, total, earnings, score, tier)
    }

    /// Calculate reputation bonus multiplier for a payout
    /// Returns the bonus multiplied amount
    public fun calculate_reputation_bonus(profile: &ResearcherProfile, base_amount: u64): u64 {
        let tier = reputation_types::tier(profile);
        reputation_types::apply_bonus(base_amount, tier)
    }

    /// Check if researcher is eligible for an achievement
    public fun check_achievement_eligibility(profile: &ResearcherProfile, achievement_type: u8): bool {
        // First Blood - first bug found
        if (achievement_type == reputation_types::achievement_first_blood()) {
            return reputation_types::total_bugs(profile) >= 1
        };

        // Critical Hunter - 5 critical bugs
        if (achievement_type == reputation_types::achievement_critical_hunter()) {
            return reputation_types::critical_bugs(profile) >= 5
        };

        // High Roller - 10 high severity bugs
        if (achievement_type == reputation_types::achievement_high_roller()) {
            return reputation_types::high_bugs(profile) >= 10
        };

        // Millionaire - 1M SUI earned
        if (achievement_type == reputation_types::achievement_millionaire()) {
            return reputation_types::total_earnings(profile) >= 1_000_000_000_000_000 // 1M SUI in MIST
        };

        // Prolific - 50 total bugs
        if (achievement_type == reputation_types::achievement_prolific()) {
            return reputation_types::total_bugs(profile) >= 50
        };

        // Legend - 100 total bugs
        if (achievement_type == reputation_types::achievement_legend()) {
            return reputation_types::total_bugs(profile) >= 100
        };

        // Category specialists require external tracking of bug categories
        // These would need to be implemented with additional tracking
        false
    }

    /// Get tier name as string
    public fun get_tier_name(tier: u8): vector<u8> {
        if (tier == reputation_types::tier_legend()) {
            b"Legend"
        } else if (tier == reputation_types::tier_platinum()) {
            b"Platinum"
        } else if (tier == reputation_types::tier_gold()) {
            b"Gold"
        } else if (tier == reputation_types::tier_silver()) {
            b"Silver"
        } else if (tier == reputation_types::tier_bronze()) {
            b"Bronze"
        } else {
            b"Newbie"
        }
    }

    /// Get tier bonus as percentage (e.g., 115 = 1.15x = 15% bonus)
    public fun get_tier_bonus_percentage(tier: u8): u64 {
        let bonus_bp = reputation_types::get_tier_bonus(tier);
        (bonus_bp * 100) / reputation_types::basis_points_max()
    }

    // ======== Helper Functions ==========

    /// Get achievement metadata
    fun get_achievement_metadata(achievement_type: u8): (vector<u8>, vector<u8>, vector<u8>) {
        if (achievement_type == reputation_types::achievement_first_blood()) {
            (b"First Blood", b"Found your first vulnerability", b"ipfs://first_blood.png")
        } else if (achievement_type == reputation_types::achievement_critical_hunter()) {
            (b"Critical Hunter", b"Found 5 critical vulnerabilities", b"ipfs://critical_hunter.png")
        } else if (achievement_type == reputation_types::achievement_high_roller()) {
            (b"High Roller", b"Found 10 high severity vulnerabilities", b"ipfs://high_roller.png")
        } else if (achievement_type == reputation_types::achievement_millionaire()) {
            (b"Millionaire", b"Earned 1M SUI in bounties", b"ipfs://millionaire.png")
        } else if (achievement_type == reputation_types::achievement_reentrancy_expert()) {
            (b"Reentrancy Expert", b"Found 10 reentrancy bugs", b"ipfs://reentrancy_expert.png")
        } else if (achievement_type == reputation_types::achievement_overflow_master()) {
            (b"Overflow Master", b"Found 10 overflow bugs", b"ipfs://overflow_master.png")
        } else if (achievement_type == reputation_types::achievement_logic_guru()) {
            (b"Logic Guru", b"Found 10 logic error bugs", b"ipfs://logic_guru.png")
        } else if (achievement_type == reputation_types::achievement_access_specialist()) {
            (b"Access Specialist", b"Found 10 access control bugs", b"ipfs://access_specialist.png")
        } else if (achievement_type == reputation_types::achievement_price_oracle_hunter()) {
            (b"Price Oracle Hunter", b"Found 10 price manipulation bugs", b"ipfs://price_oracle_hunter.png")
        } else if (achievement_type == reputation_types::achievement_prolific()) {
            (b"Prolific", b"Found 50 total bugs", b"ipfs://prolific.png")
        } else {
            (b"Legend", b"Found 100 total bugs", b"ipfs://legend.png")
        }
    }
}
