// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Archive Registry Initialization
module suiguard::archive_init {
    use sui::tx_context::TxContext;
    use sui::transfer;

    use suiguard::archive_types;

    /// One-time initialization function
    /// Creates and shares the ArchiveRegistry
    fun init(ctx: &mut TxContext) {
        let registry = archive_types::new_registry(ctx);
        archive_types::share_registry(registry);
    }

    #[test_only]
    /// Test-only initialization
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
