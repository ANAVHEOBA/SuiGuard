/// Forum Events
/// Event definitions for the forum system
module suiguard::forum_events {
    use sui::object::ID;
    use sui::event;

    /// Emitted when a new forum is created
    public struct ForumCreated has copy, drop {
        forum_id: ID,
        category: u8,
        created_at: u64,
    }

    /// Emitted when a new post is created
    public struct PostCreated has copy, drop {
        post_id: ID,
        forum_id: ID,
        author: address,
        created_at: u64,
    }

    /// Emitted when a reply is posted
    public struct ReplyPosted has copy, drop {
        reply_id: ID,
        post_id: ID,
        author: address,
        parent_reply_id: Option<ID>,
        created_at: u64,
    }

    /// Emitted when a post or reply is upvoted
    public struct Upvoted has copy, drop {
        content_id: ID,
        voter: address,
        is_post: bool,                      // true for post, false for reply
    }

    /// Emitted when an upvote is removed
    public struct UpvoteRemoved has copy, drop {
        content_id: ID,
        voter: address,
        is_post: bool,
    }

    /// Emitted when a post is locked by a moderator
    public struct PostLocked has copy, drop {
        post_id: ID,
        moderator: address,
        timestamp: u64,
    }

    /// Emitted when a post is deleted
    public struct PostDeleted has copy, drop {
        post_id: ID,
        moderator: address,
        timestamp: u64,
    }

    /// Emitted when a post is pinned
    public struct PostPinned has copy, drop {
        post_id: ID,
        moderator: address,
        timestamp: u64,
    }

    /// Emitted when a moderator is added to a forum
    public struct ModeratorAdded has copy, drop {
        forum_id: ID,
        moderator: address,
        added_by: address,
        timestamp: u64,
    }

    /// Emitted when a moderator is removed from a forum
    public struct ModeratorRemoved has copy, drop {
        forum_id: ID,
        moderator: address,
        removed_by: address,
        timestamp: u64,
    }

    // ========== Event Emitters (package-only) ==========

    public(package) fun emit_forum_created(
        forum_id: ID,
        category: u8,
        created_at: u64,
    ) {
        event::emit(ForumCreated {
            forum_id,
            category,
            created_at,
        });
    }

    public(package) fun emit_post_created(
        post_id: ID,
        forum_id: ID,
        author: address,
        created_at: u64,
    ) {
        event::emit(PostCreated {
            post_id,
            forum_id,
            author,
            created_at,
        });
    }

    public(package) fun emit_reply_posted(
        reply_id: ID,
        post_id: ID,
        author: address,
        parent_reply_id: Option<ID>,
        created_at: u64,
    ) {
        event::emit(ReplyPosted {
            reply_id,
            post_id,
            author,
            parent_reply_id,
            created_at,
        });
    }

    public(package) fun emit_upvoted(
        content_id: ID,
        voter: address,
        is_post: bool,
    ) {
        event::emit(Upvoted {
            content_id,
            voter,
            is_post,
        });
    }

    public(package) fun emit_upvote_removed(
        content_id: ID,
        voter: address,
        is_post: bool,
    ) {
        event::emit(UpvoteRemoved {
            content_id,
            voter,
            is_post,
        });
    }

    public(package) fun emit_post_locked(
        post_id: ID,
        moderator: address,
        timestamp: u64,
    ) {
        event::emit(PostLocked {
            post_id,
            moderator,
            timestamp,
        });
    }

    public(package) fun emit_post_deleted(
        post_id: ID,
        moderator: address,
        timestamp: u64,
    ) {
        event::emit(PostDeleted {
            post_id,
            moderator,
            timestamp,
        });
    }

    public(package) fun emit_post_pinned(
        post_id: ID,
        moderator: address,
        timestamp: u64,
    ) {
        event::emit(PostPinned {
            post_id,
            moderator,
            timestamp,
        });
    }

    public(package) fun emit_moderator_added(
        forum_id: ID,
        moderator: address,
        added_by: address,
        timestamp: u64,
    ) {
        event::emit(ModeratorAdded {
            forum_id,
            moderator,
            added_by,
            timestamp,
        });
    }

    public(package) fun emit_moderator_removed(
        forum_id: ID,
        moderator: address,
        removed_by: address,
        timestamp: u64,
    ) {
        event::emit(ModeratorRemoved {
            forum_id,
            moderator,
            removed_by,
            timestamp,
        });
    }
}
