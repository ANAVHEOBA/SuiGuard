/// Forum API
/// Public functions for creating forums, posts, and replies
module suiguard::forum_api {
    use std::option;
    use sui::object;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::vec_set;

    use suiguard::forum_types::{Self, ForumRegistry, Forum, Post, Reply, VoteRecord};
    use suiguard::forum_events;
    use suiguard::walrus;
    use suiguard::reputation_types::ResearcherProfile;

    /// Error codes (7000-7999 for forum module)
    const E_INSUFFICIENT_REPUTATION: u64 = 7001;
    const E_NOT_MODERATOR: u64 = 7002;
    const E_POST_LOCKED: u64 = 7003;
    const E_POST_DELETED: u64 = 7004;
    const E_ALREADY_VOTED: u64 = 7005;
    const E_NOT_VOTED: u64 = 7006;
    const E_INVALID_TITLE: u64 = 7007;
    const E_FORUM_EXISTS: u64 = 7008;

    // ========== Initialization ==========

    /// Initialize the forum registry (called once during deployment)
    fun init(ctx: &mut TxContext) {
        let registry = forum_types::new_registry(ctx);
        forum_types::share_registry(registry);

        let votes = forum_types::new_vote_record(ctx);
        forum_types::share_vote_record(votes);
    }

    // ========== Public API ==========

    /// Create a new forum category
    /// Only callable by platform admins (in production, add admin check)
    public entry fun create_forum(
        registry: &mut ForumRegistry,
        category: u8,
        name: vector<u8>,
        description: vector<u8>,
        min_reputation_to_post: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        // Check if forum already exists for this category
        assert!(!forum_types::has_forum_category(registry, category), E_FORUM_EXISTS);

        let timestamp = clock::timestamp_ms(clock);
        let creator = tx_context::sender(ctx);

        // Create moderator set with creator as first moderator
        let mut moderators = vec_set::empty<address>();
        vec_set::insert(&mut moderators, creator);

        // Create forum
        let forum = forum_types::new_forum(
            category,
            name,
            description,
            moderators,
            min_reputation_to_post,
            timestamp,
            ctx,
        );

        let forum_id = object::id(&forum);

        // Update registry
        forum_types::add_forum_category(registry, category, forum_id);

        // Emit event
        forum_events::emit_forum_created(forum_id, category, timestamp);

        // Share forum as a shared object so anyone can read it
        forum_types::share_forum(forum);
    }

    /// Create a new post in a forum
    public entry fun create_post(
        registry: &mut ForumRegistry,
        forum: &mut Forum,
        profile: &ResearcherProfile,
        title: vector<u8>,
        walrus_blob_id: vector<u8>,
        tags: vector<vector<u8>>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let author = tx_context::sender(ctx);

        // Validate title not empty
        assert!(std::vector::length(&title) > 0, E_INVALID_TITLE);

        // Check reputation requirement (using total bugs found as reputation metric)
        let user_reputation = suiguard::reputation_types::total_bugs(profile);
        assert!(user_reputation >= forum_types::min_reputation_to_post(forum), E_INSUFFICIENT_REPUTATION);

        // Validate Walrus blob ID
        walrus::validate_blob_id(&walrus_blob_id);

        let timestamp = clock::timestamp_ms(clock);
        let forum_id = object::id(forum);

        // Create post
        let post = forum_types::new_post(
            forum_id,
            author,
            title,
            walrus_blob_id,
            tags,
            timestamp,
            ctx,
        );

        let post_id = object::id(&post);

        // Update forum
        forum_types::increment_post_count(forum);
        forum_types::update_forum_last_post(forum, timestamp);

        // Update registry
        forum_types::increment_total_posts(registry);

        // Emit event
        forum_events::emit_post_created(post_id, forum_id, author, timestamp);

        // Transfer post to author
        forum_types::transfer_post(post, author);
    }

    /// Reply to a post
    public entry fun reply_to_post(
        registry: &mut ForumRegistry,
        post: &mut Post,
        walrus_blob_id: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let author = tx_context::sender(ctx);

        // Check post is not locked or deleted
        assert!(forum_types::status(post) != forum_types::status_locked(), E_POST_LOCKED);
        assert!(forum_types::status(post) != forum_types::status_deleted(), E_POST_DELETED);

        // Validate Walrus blob ID
        walrus::validate_blob_id(&walrus_blob_id);

        let timestamp = clock::timestamp_ms(clock);
        let post_id = object::id(post);

        // Create reply
        let reply = forum_types::new_reply(
            post_id,
            author,
            walrus_blob_id,
            option::none(),
            timestamp,
            ctx,
        );

        let reply_id = object::id(&reply);

        // Update post
        forum_types::increment_reply_count(post);
        forum_types::update_post_last_reply(post, timestamp);

        // Update registry
        forum_types::increment_total_replies(registry);

        // Emit event
        forum_events::emit_reply_posted(reply_id, post_id, author, option::none(), timestamp);

        // Transfer reply to author
        forum_types::transfer_reply(reply, author);
    }

    /// Reply to another reply (nested reply)
    public entry fun reply_to_reply(
        registry: &mut ForumRegistry,
        post: &mut Post,
        parent_reply_id: sui::object::ID,
        walrus_blob_id: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let author = tx_context::sender(ctx);

        // Check post is not locked or deleted
        assert!(forum_types::status(post) != forum_types::status_locked(), E_POST_LOCKED);
        assert!(forum_types::status(post) != forum_types::status_deleted(), E_POST_DELETED);

        // Validate Walrus blob ID
        walrus::validate_blob_id(&walrus_blob_id);

        let timestamp = clock::timestamp_ms(clock);
        let post_id = object::id(post);

        // Create reply
        let reply = forum_types::new_reply(
            post_id,
            author,
            walrus_blob_id,
            option::some(parent_reply_id),
            timestamp,
            ctx,
        );

        let reply_id = object::id(&reply);

        // Update post
        forum_types::increment_reply_count(post);
        forum_types::update_post_last_reply(post, timestamp);

        // Update registry
        forum_types::increment_total_replies(registry);

        // Emit event
        forum_events::emit_reply_posted(
            reply_id,
            post_id,
            author,
            option::some(parent_reply_id),
            timestamp
        );

        // Transfer reply to author
        forum_types::transfer_reply(reply, author);
    }

    /// Upvote a post
    public entry fun upvote_post(
        votes: &mut VoteRecord,
        post: &mut Post,
        ctx: &mut TxContext,
    ) {
        let voter = tx_context::sender(ctx);
        let post_id = object::id(post);

        // Check if already voted
        assert!(!forum_types::has_upvoted(votes, voter, post_id), E_ALREADY_VOTED);

        // Record vote
        forum_types::record_upvote(votes, voter, post_id, ctx);

        // Increment upvote count
        forum_types::upvote_post(post);

        // Emit event
        forum_events::emit_upvoted(post_id, voter, true);
    }

    /// Remove upvote from a post
    public entry fun remove_post_upvote(
        votes: &mut VoteRecord,
        post: &mut Post,
        _ctx: &mut TxContext,
    ) {
        let voter = tx_context::sender(_ctx);
        let post_id = object::id(post);

        // Check if voted
        assert!(forum_types::has_upvoted(votes, voter, post_id), E_NOT_VOTED);

        // Remove vote
        forum_types::remove_upvote(votes, voter, post_id);

        // Decrement upvote count
        forum_types::downvote_post(post);

        // Emit event
        forum_events::emit_upvote_removed(post_id, voter, true);
    }

    /// Upvote a reply
    public entry fun upvote_reply(
        votes: &mut VoteRecord,
        reply: &mut Reply,
        ctx: &mut TxContext,
    ) {
        let voter = tx_context::sender(ctx);
        let reply_id = object::id(reply);

        // Check if already voted
        assert!(!forum_types::has_upvoted(votes, voter, reply_id), E_ALREADY_VOTED);

        // Record vote
        forum_types::record_upvote(votes, voter, reply_id, ctx);

        // Increment upvote count
        forum_types::upvote_reply(reply);

        // Emit event
        forum_events::emit_upvoted(reply_id, voter, false);
    }

    /// Remove upvote from a reply
    public entry fun remove_reply_upvote(
        votes: &mut VoteRecord,
        reply: &mut Reply,
        _ctx: &mut TxContext,
    ) {
        let voter = tx_context::sender(_ctx);
        let reply_id = object::id(reply);

        // Check if voted
        assert!(forum_types::has_upvoted(votes, voter, reply_id), E_NOT_VOTED);

        // Remove vote
        forum_types::remove_upvote(votes, voter, reply_id);

        // Decrement upvote count
        forum_types::downvote_reply(reply);

        // Emit event
        forum_events::emit_upvote_removed(reply_id, voter, false);
    }

    // ========== Moderation Functions ==========

    /// Lock a post (moderators only)
    public entry fun lock_post(
        forum: &Forum,
        post: &mut Post,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let moderator = tx_context::sender(ctx);

        // Check is moderator
        assert!(forum_types::is_moderator(forum, moderator), E_NOT_MODERATOR);

        // Lock post
        forum_types::lock_post(post);

        let timestamp = clock::timestamp_ms(clock);

        // Emit event
        forum_events::emit_post_locked(object::id(post), moderator, timestamp);
    }

    /// Delete a post (moderators only)
    public entry fun delete_post(
        forum: &Forum,
        post: &mut Post,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let moderator = tx_context::sender(ctx);

        // Check is moderator
        assert!(forum_types::is_moderator(forum, moderator), E_NOT_MODERATOR);

        // Delete post
        forum_types::delete_post(post);

        let timestamp = clock::timestamp_ms(clock);

        // Emit event
        forum_events::emit_post_deleted(object::id(post), moderator, timestamp);
    }

    /// Pin a post (moderators only)
    public entry fun pin_post(
        forum: &Forum,
        post: &mut Post,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let moderator = tx_context::sender(ctx);

        // Check is moderator
        assert!(forum_types::is_moderator(forum, moderator), E_NOT_MODERATOR);

        // Pin post
        forum_types::pin_post(post);

        let timestamp = clock::timestamp_ms(clock);

        // Emit event
        forum_events::emit_post_pinned(object::id(post), moderator, timestamp);
    }

    /// Add a moderator to a forum (existing moderators only)
    public entry fun add_moderator(
        forum: &mut Forum,
        new_moderator: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let caller = tx_context::sender(ctx);

        // Check caller is moderator
        assert!(forum_types::is_moderator(forum, caller), E_NOT_MODERATOR);

        // Add new moderator
        forum_types::add_moderator(forum, new_moderator);

        let timestamp = clock::timestamp_ms(clock);

        // Emit event
        forum_events::emit_moderator_added(object::id(forum), new_moderator, caller, timestamp);
    }

    /// Remove a moderator from a forum (existing moderators only)
    public entry fun remove_moderator(
        forum: &mut Forum,
        moderator_to_remove: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let caller = tx_context::sender(ctx);

        // Check caller is moderator
        assert!(forum_types::is_moderator(forum, caller), E_NOT_MODERATOR);

        // Remove moderator
        forum_types::remove_moderator(forum, moderator_to_remove);

        let timestamp = clock::timestamp_ms(clock);

        // Emit event
        forum_events::emit_moderator_removed(object::id(forum), moderator_to_remove, caller, timestamp);
    }

    // ========== Testing Functions ==========

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
