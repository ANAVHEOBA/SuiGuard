// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Platform Statistics API
/// Provides security dashboard and leaderboard functions
module suiguard::statistics_api {
    use sui::object;
    use sui::tx_context::{Self, TxContext};
    use sui::table;
    use sui::vec_map;

    use suiguard::statistics_types::{Self, PlatformStatistics, Leaderboard, ResearcherStats, ProgramMetrics};
    use suiguard::reputation_types::{Self, ResearcherProfile};
    use suiguard::bounty_types::{Self, BountyProgram};
    use suiguard::report_types::{Self, BugReport};
    use suiguard::archive_types;

    // ======== Error Codes ========

    const E_NOT_AUTHORIZED: u64 = 11000;

    // ======== Statistics Update Functions ========

    /// Record new bounty program creation
    /// Should be called from bounty_api when program is created
    public fun record_program_created(
        stats: &mut PlatformStatistics,
        escrow_amount: u64,
        ctx: &TxContext,
    ) {
        statistics_types::increment_programs(stats);
        statistics_types::add_tvl(stats, escrow_amount);
        statistics_types::update_timestamp(stats, tx_context::epoch(ctx));
    }

    /// Record report submission
    /// Should be called from report_api when report is submitted
    public fun record_report_submission(
        stats: &mut PlatformStatistics,
        category: u8,
        severity: u8,
        ctx: &TxContext,
    ) {
        let cwe_id = archive_types::category_to_cwe(category);
        statistics_types::record_report_submitted(stats, category, severity, cwe_id);
        statistics_types::update_timestamp(stats, tx_context::epoch(ctx));
    }

    /// Record report acceptance
    public fun record_report_acceptance(
        stats: &mut PlatformStatistics,
        ctx: &TxContext,
    ) {
        statistics_types::record_report_accepted(stats);
        statistics_types::update_timestamp(stats, tx_context::epoch(ctx));
    }

    /// Record payout execution
    /// Should be called from payout_api when payout is executed
    public fun record_payout_execution(
        stats: &mut PlatformStatistics,
        report: &BugReport,
        payout_amount: u64,
        ctx: &TxContext,
    ) {
        let submitted_at = report_types::submitted_at(report);
        let current_epoch = tx_context::epoch(ctx);
        let response_time = current_epoch - submitted_at;

        statistics_types::record_payout(stats, payout_amount, response_time);
        statistics_types::update_timestamp(stats, current_epoch);
    }

    // ======== Leaderboard Update Functions ========

    /// Update researcher leaderboard entry
    /// Should be called after payout or reputation update
    public entry fun update_researcher_leaderboard(
        leaderboard: &mut Leaderboard,
        profile: &ResearcherProfile,
        ctx: &TxContext,
    ) {
        let researcher = reputation_types::researcher(profile);
        let total_earnings = reputation_types::total_earnings(profile);
        let total_bugs = reputation_types::total_bugs(profile);
        let critical_bugs = reputation_types::critical_bugs(profile);
        let high_bugs = reputation_types::high_bugs(profile);
        let reputation_score = reputation_types::reputation_score(profile);
        let last_submission = tx_context::epoch(ctx);

        let stats = statistics_types::new_researcher_stats(
            researcher,
            total_earnings,
            total_bugs,
            critical_bugs,
            high_bugs,
            reputation_score,
            last_submission,
        );

        // Update all leaderboard categories
        statistics_types::update_leaderboard_by_earnings(leaderboard, researcher, stats);
        statistics_types::update_leaderboard_by_bugs(leaderboard, researcher, stats);
        statistics_types::update_leaderboard_by_reputation(leaderboard, researcher, stats);
        statistics_types::update_leaderboard_timestamp(leaderboard, last_submission);
    }

    /// Update program security metrics
    /// Calculates and updates security score for a program
    public entry fun update_program_metrics(
        leaderboard: &mut Leaderboard,
        program: &BountyProgram,
        bugs_found: u64,
        bugs_resolved: u64,
        critical_bugs: u64,
        total_payout: u64,
        avg_response_time: u64,
        ctx: &TxContext,
    ) {
        let program_id = object::uid_to_inner(bounty_types::id(program));
        let program_name = *bounty_types::name(program);
        let tvl = bounty_types::total_escrow_value(program);

        // Calculate security score (0-1000)
        // Formula: (1000 - (bugs_found * 10)) + (bugs_resolved * 5) - (critical_bugs * 20)
        // Bounded to 0-1000 range
        let mut security_score = 1000;

        // Deduct for bugs found (max 50 bugs = -500 points)
        let bugs_penalty = if (bugs_found > 50) { 500 } else { bugs_found * 10 };
        security_score = if (security_score > bugs_penalty) { security_score - bugs_penalty } else { 0 };

        // Add for bugs resolved (up to +250 points)
        let resolved_bonus = if (bugs_resolved > 50) { 250 } else { bugs_resolved * 5 };
        security_score = security_score + resolved_bonus;
        if (security_score > 1000) { security_score = 1000 };

        // Deduct for critical bugs (max 25 critical = -500 points)
        let critical_penalty = if (critical_bugs > 25) { 500 } else { critical_bugs * 20 };
        security_score = if (security_score > critical_penalty) { security_score - critical_penalty } else { 0 };

        let metrics = statistics_types::new_program_metrics(
            program_id,
            program_name,
            tvl,
            bugs_found,
            bugs_resolved,
            critical_bugs,
            total_payout,
            avg_response_time,
            security_score,
        );

        statistics_types::update_program_metrics(leaderboard, program_id, metrics);
        statistics_types::update_leaderboard_timestamp(leaderboard, tx_context::epoch(ctx));
    }

    // ======== View Functions ========

    /// Get comprehensive platform statistics
    /// Returns (tvl, payouts, submitted, accepted, resolved, researchers, programs, avg_response_time)
    public fun get_platform_stats(stats: &PlatformStatistics): (u64, u64, u64, u64, u64, u64, u64, u64) {
        let tvl = statistics_types::total_tvl(stats);
        let payouts = statistics_types::total_payouts(stats);
        let submitted = statistics_types::total_reports_submitted(stats);
        let accepted = statistics_types::total_reports_accepted(stats);
        let resolved = statistics_types::total_reports_resolved(stats);
        let researchers = statistics_types::total_researchers(stats);
        let programs = statistics_types::total_programs(stats);
        let avg_time = statistics_types::avg_response_time(stats);

        (tvl, payouts, submitted, accepted, resolved, researchers, programs, avg_time)
    }

    /// Get vulnerability type distribution
    /// Returns count for specific category
    public fun get_vulnerability_count(stats: &PlatformStatistics, category: u8): u64 {
        let distribution = statistics_types::vulnerability_distribution(stats);
        if (table::contains(distribution, category)) {
            *table::borrow(distribution, category)
        } else {
            0
        }
    }

    /// Get CWE type distribution
    public fun get_cwe_count(stats: &PlatformStatistics, cwe_id: u16): u64 {
        let distribution = statistics_types::cwe_distribution(stats);
        if (table::contains(distribution, cwe_id)) {
            *table::borrow(distribution, cwe_id)
        } else {
            0
        }
    }

    /// Get severity distribution
    public fun get_severity_count(stats: &PlatformStatistics, severity: u8): u64 {
        let distribution = statistics_types::severity_distribution(stats);
        if (table::contains(distribution, severity)) {
            *table::borrow(distribution, severity)
        } else {
            0
        }
    }

    /// Get response time statistics
    /// Returns (min, max, avg)
    public fun get_response_times(stats: &PlatformStatistics): (u64, u64, u64) {
        let min = statistics_types::min_response_time(stats);
        let max = statistics_types::max_response_time(stats);
        let avg = statistics_types::avg_response_time(stats);

        (min, max, avg)
    }

    /// Get most common vulnerability types
    /// Returns top N categories with their counts
    public fun get_most_common_vulnerabilities(
        stats: &PlatformStatistics,
        limit: u64,
    ): vector<u8> {
        // Note: This is a simplified version that returns category IDs
        // In a full implementation, this would sort by count and return top N
        let mut categories = std::vector::empty<u8>();
        let mut i = 0u8;

        while (i < 8 && std::vector::length(&categories) < limit) {
            let count = get_vulnerability_count(stats, i);
            if (count > 0) {
                std::vector::push_back(&mut categories, i);
            };
            i = i + 1;
        };

        categories
    }

    // ======== Leaderboard Functions ========

    /// Get top researchers by earnings
    public fun get_leaderboard_by_earnings(
        leaderboard: &Leaderboard,
        limit: u64,
    ): vector<statistics_types::LeaderboardEntry> {
        let board = statistics_types::top_by_earnings(leaderboard);
        let mut result = std::vector::empty<statistics_types::LeaderboardEntry>();
        let size = vec_map::size(board);
        let actual_limit = if (limit > size) { size } else { limit };

        let mut i = 0;
        while (i < actual_limit) {
            let (researcher, stats) = vec_map::get_entry_by_idx(board, i);
            let earnings = statistics_types::researcher_total_earnings(stats);
            let bugs = statistics_types::researcher_total_bugs(stats);
            let reputation = statistics_types::researcher_reputation_score(stats);

            let entry = statistics_types::new_leaderboard_entry(*researcher, earnings, bugs, reputation);
            std::vector::push_back(&mut result, entry);
            i = i + 1;
        };

        result
    }

    /// Get top researchers by total bugs found
    public fun get_leaderboard_by_bugs(
        leaderboard: &Leaderboard,
        limit: u64,
    ): vector<statistics_types::LeaderboardEntry> {
        let board = statistics_types::top_by_bugs(leaderboard);
        let mut result = std::vector::empty<statistics_types::LeaderboardEntry>();
        let size = vec_map::size(board);
        let actual_limit = if (limit > size) { size } else { limit };

        let mut i = 0;
        while (i < actual_limit) {
            let (researcher, stats) = vec_map::get_entry_by_idx(board, i);
            let earnings = statistics_types::researcher_total_earnings(stats);
            let bugs = statistics_types::researcher_total_bugs(stats);
            let reputation = statistics_types::researcher_reputation_score(stats);

            let entry = statistics_types::new_leaderboard_entry(*researcher, earnings, bugs, reputation);
            std::vector::push_back(&mut result, entry);
            i = i + 1;
        };

        result
    }

    /// Get top researchers by reputation score
    public fun get_leaderboard_by_reputation(
        leaderboard: &Leaderboard,
        limit: u64,
    ): vector<statistics_types::LeaderboardEntry> {
        let board = statistics_types::top_by_reputation(leaderboard);
        let mut result = std::vector::empty<statistics_types::LeaderboardEntry>();
        let size = vec_map::size(board);
        let actual_limit = if (limit > size) { size } else { limit };

        let mut i = 0;
        while (i < actual_limit) {
            let (researcher, stats) = vec_map::get_entry_by_idx(board, i);
            let earnings = statistics_types::researcher_total_earnings(stats);
            let bugs = statistics_types::researcher_total_bugs(stats);
            let reputation = statistics_types::researcher_reputation_score(stats);

            let entry = statistics_types::new_leaderboard_entry(*researcher, earnings, bugs, reputation);
            std::vector::push_back(&mut result, entry);
            i = i + 1;
        };

        result
    }

    /// Get most secure programs
    public fun get_most_secure_programs(
        leaderboard: &Leaderboard,
        limit: u64,
    ): vector<statistics_types::ProgramRankEntry> {
        let programs = statistics_types::secure_programs(leaderboard);
        let mut result = std::vector::empty<statistics_types::ProgramRankEntry>();
        let size = vec_map::size(programs);
        let actual_limit = if (limit > size) { size } else { limit };

        let mut i = 0;
        while (i < actual_limit) {
            let (program_id, metrics) = vec_map::get_entry_by_idx(programs, i);
            let score = statistics_types::program_security_score(metrics);
            let bugs = statistics_types::program_bugs_found(metrics);
            let tvl = statistics_types::program_tvl(metrics);

            let entry = statistics_types::new_program_rank_entry(*program_id, score, bugs, tvl);
            std::vector::push_back(&mut result, entry);
            i = i + 1;
        };

        result
    }

    /// Get researcher rank by earnings
    /// Returns rank (1-indexed), or 0 if not in leaderboard
    public fun get_researcher_rank_by_earnings(
        leaderboard: &Leaderboard,
        researcher: address,
    ): u64 {
        let board = statistics_types::top_by_earnings(leaderboard);
        let size = vec_map::size(board);

        let mut i = 0;
        while (i < size) {
            let (addr, _) = vec_map::get_entry_by_idx(board, i);
            if (*addr == researcher) {
                return i + 1
            };
            i = i + 1;
        };

        0
    }

    /// Calculate acceptance rate
    public fun get_acceptance_rate(stats: &PlatformStatistics): u64 {
        let submitted = statistics_types::total_reports_submitted(stats);
        if (submitted == 0) {
            return 0
        };

        let accepted = statistics_types::total_reports_accepted(stats);
        (accepted * 100) / submitted
    }

    /// Calculate resolution rate
    public fun get_resolution_rate(stats: &PlatformStatistics): u64 {
        let accepted = statistics_types::total_reports_accepted(stats);
        if (accepted == 0) {
            return 0
        };

        let resolved = statistics_types::total_reports_resolved(stats);
        (resolved * 100) / accepted
    }
}
