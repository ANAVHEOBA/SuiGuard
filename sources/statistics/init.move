// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Statistics Initialization
module suiguard::statistics_init {
    use sui::tx_context::TxContext;

    use suiguard::statistics_types;

    /// One-time initialization function
    /// Creates and shares PlatformStatistics and Leaderboard
    fun init(ctx: &mut TxContext) {
        let stats = statistics_types::new_platform_statistics(ctx);
        statistics_types::share_statistics(stats);

        // Create leaderboard with top 100 entries
        let leaderboard = statistics_types::new_leaderboard(100, ctx);
        statistics_types::share_leaderboard(leaderboard);
    }

    #[test_only]
    /// Test-only initialization
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
