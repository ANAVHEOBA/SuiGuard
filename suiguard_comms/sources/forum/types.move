/// Forum Data Models
/// Defines all structs and types for the community forum system
module suiguard::forum_types {
    use std::option::Option;
    use sui::object::{UID, ID};
    use sui::tx_context::TxContext;
    use sui::vec_set::VecSet;
    use sui::table::Table;

    /// Forum categories
    const CATEGORY_EDUCATION: u8 = 0;
    const CATEGORY_DISCLOSED_VULNS: u8 = 1;
    const CATEGORY_PLATFORM_GOVERNANCE: u8 = 2;
    const CATEGORY_TOOLS_RESOURCES: u8 = 3;
    const CATEGORY_CAREERS: u8 = 4;
    const CATEGORY_GENERAL: u8 = 5;

    /// Post status
    const STATUS_ACTIVE: u8 = 0;
    const STATUS_LOCKED: u8 = 1;
    const STATUS_DELETED: u8 = 2;
    const STATUS_PINNED: u8 = 3;

    /// Shared registry for all forums
    public struct ForumRegistry has key {
        id: UID,
        // Maps category -> forum ID
        category_forums: Table<u8, ID>,
        total_forums: u64,
        total_posts: u64,
        total_replies: u64,
    }

    /// A forum category
    public struct Forum has key, store {
        id: UID,
        category: u8,
        name: vector<u8>,
        description: vector<u8>,
        created_at: u64,
        // Moderation
        moderators: VecSet<address>,
        min_reputation_to_post: u64,          // Reputation gate for posting
        post_count: u64,
        // Latest activity
        last_post_at: Option<u64>,
    }

    /// A discussion post
    public struct Post has key, store {
        id: UID,
        forum_id: ID,
        author: address,
        title: vector<u8>,
        // Content stored on Walrus
        walrus_blob_id: vector<u8>,
        created_at: u64,
        updated_at: u64,
        status: u8,
        // Engagement
        reply_count: u64,
        upvotes: u64,
        // Tags for searchability
        tags: vector<vector<u8>>,
        // Latest activity
        last_reply_at: Option<u64>,
    }

    /// A reply to a post
    public struct Reply has key, store {
        id: UID,
        post_id: ID,
        author: address,
        // Content stored on Walrus
        walrus_blob_id: vector<u8>,
        created_at: u64,
        updated_at: u64,
        // Engagement
        upvotes: u64,
        // Support for nested replies (optional parent reply)
        parent_reply_id: Option<ID>,
    }

    /// Vote tracking for posts and replies
    public struct VoteRecord has key {
        id: UID,
        // Maps user -> set of content IDs they've upvoted
        user_upvotes: Table<address, VecSet<ID>>,
    }

    // ========== Constructor Functions (package-only) ==========

    public(package) fun new_registry(ctx: &mut TxContext): ForumRegistry {
        ForumRegistry {
            id: sui::object::new(ctx),
            category_forums: sui::table::new(ctx),
            total_forums: 0,
            total_posts: 0,
            total_replies: 0,
        }
    }

    public(package) fun new_vote_record(ctx: &mut TxContext): VoteRecord {
        VoteRecord {
            id: sui::object::new(ctx),
            user_upvotes: sui::table::new(ctx),
        }
    }

    public(package) fun new_forum(
        category: u8,
        name: vector<u8>,
        description: vector<u8>,
        moderators: VecSet<address>,
        min_reputation_to_post: u64,
        created_at: u64,
        ctx: &mut TxContext,
    ): Forum {
        Forum {
            id: sui::object::new(ctx),
            category,
            name,
            description,
            created_at,
            moderators,
            min_reputation_to_post,
            post_count: 0,
            last_post_at: std::option::none(),
        }
    }

    public(package) fun new_post(
        forum_id: ID,
        author: address,
        title: vector<u8>,
        walrus_blob_id: vector<u8>,
        tags: vector<vector<u8>>,
        created_at: u64,
        ctx: &mut TxContext,
    ): Post {
        Post {
            id: sui::object::new(ctx),
            forum_id,
            author,
            title,
            walrus_blob_id,
            created_at,
            updated_at: created_at,
            status: STATUS_ACTIVE,
            reply_count: 0,
            upvotes: 0,
            tags,
            last_reply_at: std::option::none(),
        }
    }

    public(package) fun new_reply(
        post_id: ID,
        author: address,
        walrus_blob_id: vector<u8>,
        parent_reply_id: Option<ID>,
        created_at: u64,
        ctx: &mut TxContext,
    ): Reply {
        Reply {
            id: sui::object::new(ctx),
            post_id,
            author,
            walrus_blob_id,
            created_at,
            updated_at: created_at,
            upvotes: 0,
            parent_reply_id,
        }
    }

    // ========== Registry Getters ==========

    public fun registry_id(registry: &ForumRegistry): &UID {
        &registry.id
    }

    public fun total_forums(registry: &ForumRegistry): u64 {
        registry.total_forums
    }

    public fun total_posts(registry: &ForumRegistry): u64 {
        registry.total_posts
    }

    public fun total_replies(registry: &ForumRegistry): u64 {
        registry.total_replies
    }

    public fun get_forum_by_category(registry: &ForumRegistry, category: u8): &ID {
        sui::table::borrow(&registry.category_forums, category)
    }

    public fun has_forum_category(registry: &ForumRegistry, category: u8): bool {
        sui::table::contains(&registry.category_forums, category)
    }

    // ========== Forum Getters ==========

    public fun forum_id(forum: &Forum): &UID {
        &forum.id
    }

    public fun category(forum: &Forum): u8 {
        forum.category
    }

    public fun name(forum: &Forum): &vector<u8> {
        &forum.name
    }

    public fun description(forum: &Forum): &vector<u8> {
        &forum.description
    }

    public fun created_at(forum: &Forum): u64 {
        forum.created_at
    }

    public fun moderators(forum: &Forum): &VecSet<address> {
        &forum.moderators
    }

    public fun is_moderator(forum: &Forum, user: address): bool {
        sui::vec_set::contains(&forum.moderators, &user)
    }

    public fun min_reputation_to_post(forum: &Forum): u64 {
        forum.min_reputation_to_post
    }

    public fun post_count(forum: &Forum): u64 {
        forum.post_count
    }

    public fun last_post_at(forum: &Forum): &Option<u64> {
        &forum.last_post_at
    }

    // ========== Post Getters ==========

    public fun post_id(post: &Post): &UID {
        &post.id
    }

    public fun post_forum_id(post: &Post): ID {
        post.forum_id
    }

    public fun author(post: &Post): address {
        post.author
    }

    public fun title(post: &Post): &vector<u8> {
        &post.title
    }

    public fun walrus_blob_id(post: &Post): &vector<u8> {
        &post.walrus_blob_id
    }

    public fun post_created_at(post: &Post): u64 {
        post.created_at
    }

    public fun updated_at(post: &Post): u64 {
        post.updated_at
    }

    public fun status(post: &Post): u8 {
        post.status
    }

    public fun reply_count(post: &Post): u64 {
        post.reply_count
    }

    public fun upvotes(post: &Post): u64 {
        post.upvotes
    }

    public fun tags(post: &Post): &vector<vector<u8>> {
        &post.tags
    }

    public fun last_reply_at(post: &Post): &Option<u64> {
        &post.last_reply_at
    }

    // ========== Reply Getters ==========

    public fun reply_id(reply: &Reply): &UID {
        &reply.id
    }

    public fun post_id_from_reply(reply: &Reply): ID {
        reply.post_id
    }

    public fun reply_author(reply: &Reply): address {
        reply.author
    }

    public fun reply_walrus_blob_id(reply: &Reply): &vector<u8> {
        &reply.walrus_blob_id
    }

    public fun reply_created_at(reply: &Reply): u64 {
        reply.created_at
    }

    public fun reply_updated_at(reply: &Reply): u64 {
        reply.updated_at
    }

    public fun reply_upvotes(reply: &Reply): u64 {
        reply.upvotes
    }

    public fun parent_reply_id(reply: &Reply): &Option<ID> {
        &reply.parent_reply_id
    }

    // ========== Vote Record Getters ==========

    public fun has_upvoted(votes: &VoteRecord, user: address, content_id: ID): bool {
        if (!sui::table::contains(&votes.user_upvotes, user)) {
            return false
        };
        let user_votes = sui::table::borrow(&votes.user_upvotes, user);
        sui::vec_set::contains(user_votes, &content_id)
    }

    // ========== Setters (package-only) ==========

    public(package) fun add_forum_category(
        registry: &mut ForumRegistry,
        category: u8,
        forum_id: ID,
    ) {
        sui::table::add(&mut registry.category_forums, category, forum_id);
        registry.total_forums = registry.total_forums + 1;
    }

    public(package) fun increment_total_posts(registry: &mut ForumRegistry) {
        registry.total_posts = registry.total_posts + 1;
    }

    public(package) fun increment_total_replies(registry: &mut ForumRegistry) {
        registry.total_replies = registry.total_replies + 1;
    }

    public(package) fun increment_post_count(forum: &mut Forum) {
        forum.post_count = forum.post_count + 1;
    }

    public(package) fun update_forum_last_post(forum: &mut Forum, timestamp: u64) {
        forum.last_post_at = std::option::some(timestamp);
    }

    public(package) fun add_moderator(forum: &mut Forum, moderator: address) {
        sui::vec_set::insert(&mut forum.moderators, moderator);
    }

    public(package) fun remove_moderator(forum: &mut Forum, moderator: address) {
        sui::vec_set::remove(&mut forum.moderators, &moderator);
    }

    public(package) fun increment_reply_count(post: &mut Post) {
        post.reply_count = post.reply_count + 1;
    }

    public(package) fun update_post_last_reply(post: &mut Post, timestamp: u64) {
        post.last_reply_at = std::option::some(timestamp);
    }

    public(package) fun upvote_post(post: &mut Post) {
        post.upvotes = post.upvotes + 1;
    }

    public(package) fun downvote_post(post: &mut Post) {
        if (post.upvotes > 0) {
            post.upvotes = post.upvotes - 1;
        };
    }

    public(package) fun upvote_reply(reply: &mut Reply) {
        reply.upvotes = reply.upvotes + 1;
    }

    public(package) fun downvote_reply(reply: &mut Reply) {
        if (reply.upvotes > 0) {
            reply.upvotes = reply.upvotes - 1;
        };
    }

    public(package) fun lock_post(post: &mut Post) {
        post.status = STATUS_LOCKED;
    }

    public(package) fun delete_post(post: &mut Post) {
        post.status = STATUS_DELETED;
    }

    public(package) fun pin_post(post: &mut Post) {
        post.status = STATUS_PINNED;
    }

    public(package) fun activate_post(post: &mut Post) {
        post.status = STATUS_ACTIVE;
    }

    public(package) fun record_upvote(
        votes: &mut VoteRecord,
        user: address,
        content_id: ID,
        ctx: &mut TxContext,
    ) {
        if (!sui::table::contains(&votes.user_upvotes, user)) {
            sui::table::add(&mut votes.user_upvotes, user, sui::vec_set::empty<ID>());
        };
        let user_votes = sui::table::borrow_mut(&mut votes.user_upvotes, user);
        sui::vec_set::insert(user_votes, content_id);
    }

    public(package) fun remove_upvote(
        votes: &mut VoteRecord,
        user: address,
        content_id: ID,
    ) {
        if (!sui::table::contains(&votes.user_upvotes, user)) {
            return
        };
        let user_votes = sui::table::borrow_mut(&mut votes.user_upvotes, user);
        if (sui::vec_set::contains(user_votes, &content_id)) {
            sui::vec_set::remove(user_votes, &content_id);
        };
    }

    // ========== Transfer Functions (package-only) ==========

    public(package) fun share_registry(registry: ForumRegistry) {
        sui::transfer::share_object(registry);
    }

    public(package) fun share_vote_record(votes: VoteRecord) {
        sui::transfer::share_object(votes);
    }

    public(package) fun transfer_forum(forum: Forum, recipient: address) {
        sui::transfer::transfer(forum, recipient);
    }

    public(package) fun share_forum(forum: Forum) {
        sui::transfer::share_object(forum);
    }

    public(package) fun transfer_post(post: Post, recipient: address) {
        sui::transfer::transfer(post, recipient);
    }

    public(package) fun transfer_reply(reply: Reply, recipient: address) {
        sui::transfer::transfer(reply, recipient);
    }

    // ========== Constants Accessors ==========

    public fun category_education(): u8 { CATEGORY_EDUCATION }
    public fun category_disclosed_vulns(): u8 { CATEGORY_DISCLOSED_VULNS }
    public fun category_platform_governance(): u8 { CATEGORY_PLATFORM_GOVERNANCE }
    public fun category_tools_resources(): u8 { CATEGORY_TOOLS_RESOURCES }
    public fun category_careers(): u8 { CATEGORY_CAREERS }
    public fun category_general(): u8 { CATEGORY_GENERAL }

    public fun status_active(): u8 { STATUS_ACTIVE }
    public fun status_locked(): u8 { STATUS_LOCKED }
    public fun status_deleted(): u8 { STATUS_DELETED }
    public fun status_pinned(): u8 { STATUS_PINNED }
}
