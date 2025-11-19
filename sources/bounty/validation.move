/// Input validation for bounty operations
module suiguard::bounty_validation {
    use std::vector;
    use sui::vec_map::{Self, VecMap};
    use suiguard::constants;

    // ========== Validation Functions ==========

    /// Validate escrow amount meets minimum requirement
    public fun validate_escrow_amount(amount: u64) {
        assert!(
            amount >= constants::min_escrow_amount(),
            constants::e_escrow_too_low()
        );
    }

    /// Validate program name is not empty and within length limits
    public fun validate_program_name(name: &vector<u8>) {
        let len = vector::length(name);
        assert!(len > 0, constants::e_empty_name());
        assert!(len <= 100, constants::e_name_too_long());
    }

    /// Validate severity tier amounts
    /// Ensures Critical > High > Medium > Low and all meet minimum
    public fun validate_tier_amounts(
        critical: u64,
        high: u64,
        medium: u64,
        low: u64
    ) {
        // Check minimums
        let min = constants::min_payout_amount();
        assert!(critical >= min, constants::e_payout_too_low());
        assert!(high >= min, constants::e_payout_too_low());
        assert!(medium >= min, constants::e_payout_too_low());
        assert!(low >= min, constants::e_payout_too_low());

        // Check ordering
        assert!(critical > high, constants::e_invalid_tier_order());
        assert!(high > medium, constants::e_invalid_tier_order());
        assert!(medium > low, constants::e_invalid_tier_order());
    }

    /// Validate expiry date is in the future and within allowed range
    public fun validate_expiry(current_epoch: u64, expires_at: u64) {
        let duration = expires_at - current_epoch;
        
        assert!(
            duration >= constants::min_program_duration(),
            constants::e_invalid_expiry()
        );
        assert!(
            duration <= constants::max_program_duration(),
            constants::e_invalid_expiry()
        );
    }

    /// Validate there's enough available escrow for a payout
    public fun validate_sufficient_escrow(
        available: u64,
        required: u64
    ) {
        assert!(
            available >= required,
            constants::e_insufficient_escrow()
        );
    }

    /// Validate tier configuration in VecMap
    public fun validate_tier_map(tiers: &VecMap<u8, u64>) {
        // Ensure all 5 severity levels are defined
        assert!(
            vec_map::contains(tiers, &constants::severity_critical()),
            constants::e_invalid_tier_order()
        );
        assert!(
            vec_map::contains(tiers, &constants::severity_high()),
            constants::e_invalid_tier_order()
        );
        assert!(
            vec_map::contains(tiers, &constants::severity_medium()),
            constants::e_invalid_tier_order()
        );
        assert!(
            vec_map::contains(tiers, &constants::severity_low()),
            constants::e_invalid_tier_order()
        );
        assert!(
            vec_map::contains(tiers, &constants::severity_informational()),
            constants::e_invalid_tier_order()
        );
    }
}
