/// Platform-wide constants and error codes
module suiguard::constants {

    // ========== Severity Levels ==========
    public fun severity_critical(): u8 { 0 }
    public fun severity_high(): u8 { 1 }
    public fun severity_medium(): u8 { 2 }
    public fun severity_low(): u8 { 3 }
    public fun severity_informational(): u8 { 4 }

    // ========== Minimum Amounts ==========
    /// Minimum escrow amount: 10 SUI (10 * 10^9 MIST)
    public fun min_escrow_amount(): u64 { 10_000_000_000 }

    /// Minimum bounty payout: 1 SUI
    public fun min_payout_amount(): u64 { 1_000_000_000 }

    // ========== Time Constants ==========
    /// Default disclosure period: 90 days (in epochs)
    public fun default_disclosure_period(): u64 { 90 }

    /// Minimum program duration: 30 days
    public fun min_program_duration(): u64 { 30 }

    /// Maximum program duration: 365 days
    public fun max_program_duration(): u64 { 365 }

    // ========== Error Codes: Bounty Module (1000-1999) ==========

    /// Escrow amount is below minimum requirement
    public fun e_escrow_too_low(): u64 { 1001 }

    /// Invalid severity tier configuration
    public fun e_invalid_tier_order(): u64 { 1002 }

    /// Program name is empty
    public fun e_empty_name(): u64 { 1003 }

    /// Program name exceeds maximum length
    public fun e_name_too_long(): u64 { 1004 }

    /// Payout amount is below minimum
    public fun e_payout_too_low(): u64 { 1005 }

    /// Caller is not the program owner
    public fun e_not_program_owner(): u64 { 1006 }

    /// Program is not active
    public fun e_program_not_active(): u64 { 1007 }

    /// Program has expired
    public fun e_program_expired(): u64 { 1008 }

    /// Insufficient escrow to cover payout
    public fun e_insufficient_escrow(): u64 { 1009 }

    /// Invalid expiry date
    public fun e_invalid_expiry(): u64 { 1010 }

    // ========== Error Codes: Report Module (2000-2999) ==========

    /// Report not found
    public fun e_report_not_found(): u64 { 2001 }

    /// Invalid Walrus blob ID
    public fun e_invalid_blob_id(): u64 { 2002 }

    /// Duplicate report detected
    public fun e_duplicate_report(): u64 { 2003 }

    // ========== Error Codes: Triage Module (3000-3999) ==========

    /// Insufficient stake to vote
    public fun e_insufficient_stake(): u64 { 3001 }

    /// Voting period ended
    public fun e_voting_ended(): u64 { 3002 }

    /// Triage not finalized
    public fun e_triage_not_finalized(): u64 { 3003 }

    // ========== Error Codes: Reputation Module (4000-4999) ==========

    /// Reputation not found
    public fun e_reputation_not_found(): u64 { 4001 }

    // ========== Error Codes: Integration Modules (5000-5999) ==========

    /// Invalid Nautilus attestation
    public fun e_invalid_attestation(): u64 { 5001 }

    /// Invalid Seal policy
    public fun e_invalid_seal_policy(): u64 { 5002 }

    /// Invalid Walrus configuration
    public fun e_invalid_walrus_config(): u64 { 5003 }

    // ========== Error Codes: Messaging Module (6000-6999) ==========

    /// Not a participant in the conversation
    public fun e_not_participant(): u64 { 6001 }

    /// Conversation is inactive
    public fun e_conversation_inactive(): u64 { 6002 }

    /// Invalid participants list
    public fun e_invalid_participants(): u64 { 6003 }

    /// Duplicate participants
    public fun e_duplicate_participants(): u64 { 6004 }

    /// Empty message content
    public fun e_empty_message(): u64 { 6005 }

    /// Cannot message yourself
    public fun e_cannot_message_self(): u64 { 6006 }

    // ========== Error Codes: Forum Module (7000-7999) ==========

    /// Insufficient reputation to post
    public fun e_insufficient_reputation(): u64 { 7001 }

    /// Not a moderator
    public fun e_not_moderator(): u64 { 7002 }

    /// Post is locked
    public fun e_post_locked(): u64 { 7003 }

    /// Post is deleted
    public fun e_post_deleted(): u64 { 7004 }

    /// Already voted on this content
    public fun e_already_voted(): u64 { 7005 }

    /// Have not voted on this content
    public fun e_not_voted(): u64 { 7006 }

    /// Invalid post title
    public fun e_invalid_title(): u64 { 7007 }

    /// Forum already exists for this category
    public fun e_forum_exists(): u64 { 7008 }
}
