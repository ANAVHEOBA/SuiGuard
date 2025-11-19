// Copyright (c) SuiGuard, Inc.
// SPDX-License-Identifier: MIT

/// Platform Statistics Types
/// Tracks platform-wide security metrics and leaderboards
module suiguard::statistics_types {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::TxContext;
    use sui::table::{Self, Table};
    use sui::vec_map::{Self, VecMap};

    /// Platform-wide statistics
    /// Shared object tracking ecosystem security metrics
    public struct PlatformStatistics has key {
        id: UID,
        /// Total value locked in all bounty programs (in MIST)
        total_tvl: u64,
        /// Total payouts distributed (in MIST)
        total_payouts: u64,
        /// Total bug reports submitted
        total_reports_submitted: u64,
        /// Total reports accepted
        total_reports_accepted: u64,
        /// Total reports resolved (paid)
        total_reports_resolved: u64,
        /// Total unique researchers
        total_researchers: u64,
        /// Total active bounty programs
        total_programs: u64,
        /// Vulnerability type distribution (category -> count)
        vulnerability_distribution: Table<u8, u64>,
        /// CWE type distribution (cwe_id -> count)
        cwe_distribution: Table<u16, u64>,
        /// Severity distribution (severity -> count)
        severity_distribution: Table<u8, u64>,
        /// Response time tracking
        total_response_time: u64,  // Sum of all response times (for average)
        min_response_time: u64,
        max_response_time: u64,
        /// When statistics were last updated
        last_updated: u64,
    }

    /// Researcher leaderboard entry
    public struct ResearcherStats has store, drop, copy {
        researcher: address,
        total_earnings: u64,
        total_bugs: u64,
        critical_bugs: u64,
        high_bugs: u64,
        reputation_score: u64,
        last_submission: u64,
    }

    /// Leaderboard entry (for returning from view functions)
    public struct LeaderboardEntry has drop, copy {
        researcher: address,
        earnings: u64,
        bugs: u64,
        reputation: u64,
    }

    /// Program rank entry (for returning from view functions)
    public struct ProgramRankEntry has drop, copy {
        program_id: ID,
        security_score: u64,
        bugs_found: u64,
        tvl: u64,
    }

    /// Program security metrics
    public struct ProgramMetrics has store, drop, copy {
        program_id: ID,
        program_name: vector<u8>,
        tvl: u64,
        bugs_found: u64,
        bugs_resolved: u64,
        critical_bugs: u64,
        total_payout: u64,
        avg_response_time: u64,
        security_score: u64,  // Calculated score (0-1000)
    }

    /// Leaderboard rankings
    /// Separate object for efficient querying
    public struct Leaderboard has key {
        id: UID,
        /// Top researchers by earnings (address -> stats)
        by_earnings: VecMap<address, ResearcherStats>,
        /// Top researchers by total bugs (address -> stats)
        by_bugs: VecMap<address, ResearcherStats>,
        /// Top researchers by critical bugs (address -> stats)
        by_critical: VecMap<address, ResearcherStats>,
        /// Top researchers by reputation (address -> stats)
        by_reputation: VecMap<address, ResearcherStats>,
        /// Most secure programs (program_id -> metrics)
        secure_programs: VecMap<ID, ProgramMetrics>,
        /// Maximum leaderboard size
        max_entries: u64,
        /// When leaderboard was last updated
        last_updated: u64,
    }

    // ========== Constructor Functions ==========

    /// Create new platform statistics
    public(package) fun new_platform_statistics(ctx: &mut TxContext): PlatformStatistics {
        PlatformStatistics {
            id: object::new(ctx),
            total_tvl: 0,
            total_payouts: 0,
            total_reports_submitted: 0,
            total_reports_accepted: 0,
            total_reports_resolved: 0,
            total_researchers: 0,
            total_programs: 0,
            vulnerability_distribution: table::new(ctx),
            cwe_distribution: table::new(ctx),
            severity_distribution: table::new(ctx),
            total_response_time: 0,
            min_response_time: 0,
            max_response_time: 0,
            last_updated: 0,
        }
    }

    /// Create new leaderboard
    public(package) fun new_leaderboard(max_entries: u64, ctx: &mut TxContext): Leaderboard {
        Leaderboard {
            id: object::new(ctx),
            by_earnings: vec_map::empty(),
            by_bugs: vec_map::empty(),
            by_critical: vec_map::empty(),
            by_reputation: vec_map::empty(),
            secure_programs: vec_map::empty(),
            max_entries,
            last_updated: 0,
        }
    }

    /// Create researcher stats entry
    public(package) fun new_researcher_stats(
        researcher: address,
        total_earnings: u64,
        total_bugs: u64,
        critical_bugs: u64,
        high_bugs: u64,
        reputation_score: u64,
        last_submission: u64,
    ): ResearcherStats {
        ResearcherStats {
            researcher,
            total_earnings,
            total_bugs,
            critical_bugs,
            high_bugs,
            reputation_score,
            last_submission,
        }
    }

    /// Create program metrics entry
    public(package) fun new_program_metrics(
        program_id: ID,
        program_name: vector<u8>,
        tvl: u64,
        bugs_found: u64,
        bugs_resolved: u64,
        critical_bugs: u64,
        total_payout: u64,
        avg_response_time: u64,
        security_score: u64,
    ): ProgramMetrics {
        ProgramMetrics {
            program_id,
            program_name,
            tvl,
            bugs_found,
            bugs_resolved,
            critical_bugs,
            total_payout,
            avg_response_time,
            security_score,
        }
    }

    /// Create leaderboard entry
    public fun new_leaderboard_entry(
        researcher: address,
        earnings: u64,
        bugs: u64,
        reputation: u64,
    ): LeaderboardEntry {
        LeaderboardEntry {
            researcher,
            earnings,
            bugs,
            reputation,
        }
    }

    /// Create program rank entry
    public fun new_program_rank_entry(
        program_id: ID,
        security_score: u64,
        bugs_found: u64,
        tvl: u64,
    ): ProgramRankEntry {
        ProgramRankEntry {
            program_id,
            security_score,
            bugs_found,
            tvl,
        }
    }

    // ========== Getters: PlatformStatistics ==========

    public fun stats_id(stats: &PlatformStatistics): &UID {
        &stats.id
    }

    public fun total_tvl(stats: &PlatformStatistics): u64 {
        stats.total_tvl
    }

    public fun total_payouts(stats: &PlatformStatistics): u64 {
        stats.total_payouts
    }

    public fun total_reports_submitted(stats: &PlatformStatistics): u64 {
        stats.total_reports_submitted
    }

    public fun total_reports_accepted(stats: &PlatformStatistics): u64 {
        stats.total_reports_accepted
    }

    public fun total_reports_resolved(stats: &PlatformStatistics): u64 {
        stats.total_reports_resolved
    }

    public fun total_researchers(stats: &PlatformStatistics): u64 {
        stats.total_researchers
    }

    public fun total_programs(stats: &PlatformStatistics): u64 {
        stats.total_programs
    }

    public fun vulnerability_distribution(stats: &PlatformStatistics): &Table<u8, u64> {
        &stats.vulnerability_distribution
    }

    public fun cwe_distribution(stats: &PlatformStatistics): &Table<u16, u64> {
        &stats.cwe_distribution
    }

    public fun severity_distribution(stats: &PlatformStatistics): &Table<u8, u64> {
        &stats.severity_distribution
    }

    public fun min_response_time(stats: &PlatformStatistics): u64 {
        stats.min_response_time
    }

    public fun max_response_time(stats: &PlatformStatistics): u64 {
        stats.max_response_time
    }

    /// Calculate average response time
    public fun avg_response_time(stats: &PlatformStatistics): u64 {
        if (stats.total_reports_resolved == 0) {
            return 0
        };
        stats.total_response_time / stats.total_reports_resolved
    }

    // ========== Getters: Leaderboard ==========

    public fun leaderboard_id(board: &Leaderboard): &UID {
        &board.id
    }

    public fun top_by_earnings(board: &Leaderboard): &VecMap<address, ResearcherStats> {
        &board.by_earnings
    }

    public fun top_by_bugs(board: &Leaderboard): &VecMap<address, ResearcherStats> {
        &board.by_bugs
    }

    public fun top_by_critical(board: &Leaderboard): &VecMap<address, ResearcherStats> {
        &board.by_critical
    }

    public fun top_by_reputation(board: &Leaderboard): &VecMap<address, ResearcherStats> {
        &board.by_reputation
    }

    public fun secure_programs(board: &Leaderboard): &VecMap<ID, ProgramMetrics> {
        &board.secure_programs
    }

    public fun max_entries(board: &Leaderboard): u64 {
        board.max_entries
    }

    // ========== Getters: ResearcherStats ==========

    public fun researcher_address(stats: &ResearcherStats): address {
        stats.researcher
    }

    public fun researcher_total_earnings(stats: &ResearcherStats): u64 {
        stats.total_earnings
    }

    public fun researcher_total_bugs(stats: &ResearcherStats): u64 {
        stats.total_bugs
    }

    public fun researcher_critical_bugs(stats: &ResearcherStats): u64 {
        stats.critical_bugs
    }

    public fun researcher_high_bugs(stats: &ResearcherStats): u64 {
        stats.high_bugs
    }

    public fun researcher_reputation_score(stats: &ResearcherStats): u64 {
        stats.reputation_score
    }

    // ========== Getters: ProgramMetrics ==========

    public fun program_metrics_id(metrics: &ProgramMetrics): ID {
        metrics.program_id
    }

    public fun program_metrics_name(metrics: &ProgramMetrics): &vector<u8> {
        &metrics.program_name
    }

    public fun program_tvl(metrics: &ProgramMetrics): u64 {
        metrics.tvl
    }

    public fun program_bugs_found(metrics: &ProgramMetrics): u64 {
        metrics.bugs_found
    }

    public fun program_bugs_resolved(metrics: &ProgramMetrics): u64 {
        metrics.bugs_resolved
    }

    public fun program_security_score(metrics: &ProgramMetrics): u64 {
        metrics.security_score
    }

    // ========== Mutable Functions (package-only) ==========

    /// Increment program count
    public(package) fun increment_programs(stats: &mut PlatformStatistics) {
        stats.total_programs = stats.total_programs + 1;
    }

    /// Add TVL
    public(package) fun add_tvl(stats: &mut PlatformStatistics, amount: u64) {
        stats.total_tvl = stats.total_tvl + amount;
    }

    /// Remove TVL
    public(package) fun remove_tvl(stats: &mut PlatformStatistics, amount: u64) {
        stats.total_tvl = stats.total_tvl - amount;
    }

    /// Record report submission
    public(package) fun record_report_submitted(
        stats: &mut PlatformStatistics,
        category: u8,
        severity: u8,
        cwe_id: u16,
    ) {
        stats.total_reports_submitted = stats.total_reports_submitted + 1;

        // Update category distribution
        if (!table::contains(&stats.vulnerability_distribution, category)) {
            table::add(&mut stats.vulnerability_distribution, category, 0);
        };
        let count = table::borrow_mut(&mut stats.vulnerability_distribution, category);
        *count = *count + 1;

        // Update CWE distribution
        if (!table::contains(&stats.cwe_distribution, cwe_id)) {
            table::add(&mut stats.cwe_distribution, cwe_id, 0);
        };
        let cwe_count = table::borrow_mut(&mut stats.cwe_distribution, cwe_id);
        *cwe_count = *cwe_count + 1;

        // Update severity distribution
        if (!table::contains(&stats.severity_distribution, severity)) {
            table::add(&mut stats.severity_distribution, severity, 0);
        };
        let sev_count = table::borrow_mut(&mut stats.severity_distribution, severity);
        *sev_count = *sev_count + 1;
    }

    /// Record report acceptance
    public(package) fun record_report_accepted(stats: &mut PlatformStatistics) {
        stats.total_reports_accepted = stats.total_reports_accepted + 1;
    }

    /// Record payout
    public(package) fun record_payout(
        stats: &mut PlatformStatistics,
        amount: u64,
        response_time: u64,
    ) {
        stats.total_reports_resolved = stats.total_reports_resolved + 1;
        stats.total_payouts = stats.total_payouts + amount;
        stats.total_response_time = stats.total_response_time + response_time;

        // Update min/max response times
        if (stats.min_response_time == 0 || response_time < stats.min_response_time) {
            stats.min_response_time = response_time;
        };
        if (response_time > stats.max_response_time) {
            stats.max_response_time = response_time;
        };
    }

    /// Increment unique researchers
    public(package) fun increment_researchers(stats: &mut PlatformStatistics) {
        stats.total_researchers = stats.total_researchers + 1;
    }

    /// Update timestamp
    public(package) fun update_timestamp(stats: &mut PlatformStatistics, timestamp: u64) {
        stats.last_updated = timestamp;
    }

    /// Update leaderboard entry
    public(package) fun update_leaderboard_by_earnings(
        board: &mut Leaderboard,
        researcher: address,
        stats: ResearcherStats,
    ) {
        if (vec_map::contains(&board.by_earnings, &researcher)) {
            let old_stats = vec_map::get_mut(&mut board.by_earnings, &researcher);
            *old_stats = stats;
        } else {
            vec_map::insert(&mut board.by_earnings, researcher, stats);
        };
    }

    /// Update leaderboard by bugs
    public(package) fun update_leaderboard_by_bugs(
        board: &mut Leaderboard,
        researcher: address,
        stats: ResearcherStats,
    ) {
        if (vec_map::contains(&board.by_bugs, &researcher)) {
            let old_stats = vec_map::get_mut(&mut board.by_bugs, &researcher);
            *old_stats = stats;
        } else {
            vec_map::insert(&mut board.by_bugs, researcher, stats);
        };
    }

    /// Update leaderboard by reputation
    public(package) fun update_leaderboard_by_reputation(
        board: &mut Leaderboard,
        researcher: address,
        stats: ResearcherStats,
    ) {
        if (vec_map::contains(&board.by_reputation, &researcher)) {
            let old_stats = vec_map::get_mut(&mut board.by_reputation, &researcher);
            *old_stats = stats;
        } else {
            vec_map::insert(&mut board.by_reputation, researcher, stats);
        };
    }

    /// Update program metrics
    public(package) fun update_program_metrics(
        board: &mut Leaderboard,
        program_id: ID,
        metrics: ProgramMetrics,
    ) {
        if (vec_map::contains(&board.secure_programs, &program_id)) {
            let old_metrics = vec_map::get_mut(&mut board.secure_programs, &program_id);
            *old_metrics = metrics;
        } else {
            vec_map::insert(&mut board.secure_programs, program_id, metrics);
        };
    }

    /// Update leaderboard timestamp
    public(package) fun update_leaderboard_timestamp(board: &mut Leaderboard, timestamp: u64) {
        board.last_updated = timestamp;
    }

    // ========== Share Functions ==========

    /// Share platform statistics
    public(package) fun share_statistics(stats: PlatformStatistics) {
        use sui::transfer;
        transfer::share_object(stats);
    }

    /// Share leaderboard
    public(package) fun share_leaderboard(board: Leaderboard) {
        use sui::transfer;
        transfer::share_object(board);
    }
}
