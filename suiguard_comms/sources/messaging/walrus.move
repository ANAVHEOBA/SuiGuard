// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Walrus Decentralized Storage Integration
/// Provides helper functions for interacting with Walrus blob storage.
module suiguard::walrus {
    use std::vector;

    // ======== Constants ========

    /// Minimum blob ID length (32 bytes)
    const MIN_BLOB_ID_LENGTH: u64 = 32;

    /// Maximum blob ID length (66 bytes for "0x" + 64 hex chars)
    const MAX_BLOB_ID_LENGTH: u64 = 66;

    // ======== Error Codes ========

    const E_INVALID_BLOB_ID: u64 = 1300;
    const E_BLOB_ID_TOO_SHORT: u64 = 1301;
    const E_BLOB_ID_TOO_LONG: u64 = 1302;

    // ======== Blob ID Validation ========

    /// Validate blob ID format
    /// Blob IDs should be 32-66 bytes (u256 as hex string)
    public fun validate_blob_id(blob_id: &vector<u8>): bool {
        let len = vector::length(blob_id);

        // Check length bounds
        if (len < MIN_BLOB_ID_LENGTH || len > MAX_BLOB_ID_LENGTH) {
            return false
        };

        // Empty blob ID is invalid
        if (len == 0) {
            return false
        };

        true
    }

    /// Assert blob ID is valid (aborts on failure)
    public fun assert_valid_blob_id(blob_id: &vector<u8>) {
        let len = vector::length(blob_id);

        assert!(len >= MIN_BLOB_ID_LENGTH, E_BLOB_ID_TOO_SHORT);
        assert!(len <= MAX_BLOB_ID_LENGTH, E_BLOB_ID_TOO_LONG);
        assert!(len > 0, E_INVALID_BLOB_ID);
    }

    /// Check if blob ID is empty (zero-length)
    public fun is_empty_blob_id(blob_id: &vector<u8>): bool {
        vector::length(blob_id) == 0
    }

    // ======== Blob Metadata Helpers ========

    /// Get blob ID length
    public fun blob_id_length(blob_id: &vector<u8>): u64 {
        vector::length(blob_id)
    }
}
