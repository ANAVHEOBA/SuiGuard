// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Seal Protocol Integration
/// Provides helper functions for validating Seal policy IDs.
module suiguard::seal {
    use std::vector;

    // ======== Constants ========

    /// Minimum policy ID length
    const MIN_POLICY_ID_LENGTH: u64 = 32;

    /// Maximum policy ID length
    const MAX_POLICY_ID_LENGTH: u64 = 66;

    // ======== Error Codes ========

    const E_INVALID_POLICY_ID: u64 = 1400;
    const E_POLICY_ID_TOO_SHORT: u64 = 1401;
    const E_POLICY_ID_TOO_LONG: u64 = 1402;

    // ======== Policy ID Validation ========

    /// Validate policy ID format
    public fun validate_policy_id(policy_id: &vector<u8>): bool {
        let len = vector::length(policy_id);

        // Check length bounds
        if (len < MIN_POLICY_ID_LENGTH || len > MAX_POLICY_ID_LENGTH) {
            return false
        };

        // Empty policy ID is invalid
        if (len == 0) {
            return false
        };

        true
    }

    /// Assert policy ID is valid (aborts on failure)
    public fun assert_valid_policy_id(policy_id: &vector<u8>) {
        let len = vector::length(policy_id);

        assert!(len >= MIN_POLICY_ID_LENGTH, E_POLICY_ID_TOO_SHORT);
        assert!(len <= MAX_POLICY_ID_LENGTH, E_POLICY_ID_TOO_LONG);
        assert!(len > 0, E_INVALID_POLICY_ID);
    }

    /// Check if policy ID is empty (zero-length)
    public fun is_empty_policy_id(policy_id: &vector<u8>): bool {
        vector::length(policy_id) == 0
    }

    /// Get policy ID length
    public fun policy_id_length(policy_id: &vector<u8>): u64 {
        vector::length(policy_id)
    }
}
