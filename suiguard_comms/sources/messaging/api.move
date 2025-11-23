/// Messaging API
/// Public functions for creating conversations and sending messages
module suiguard::messaging_api {
    use std::option::{Self, Option};
    use sui::object;
    use sui::tx_context::{Self, TxContext};
    use sui::clock::{Self, Clock};
    use sui::vec_set;

    use suiguard::messaging_types::{Self, ConversationRegistry, Conversation, Message};
    use suiguard::messaging_events;
    use suiguard::walrus;
    use suiguard::seal;
    use suiguard::constants;

    /// Error codes (6000-6999 for messaging module)
    const E_NOT_PARTICIPANT: u64 = 6001;
    const E_CONVERSATION_INACTIVE: u64 = 6002;
    const E_INVALID_PARTICIPANTS: u64 = 6003;
    const E_DUPLICATE_PARTICIPANTS: u64 = 6004;
    const E_EMPTY_MESSAGE: u64 = 6005;
    const E_CANNOT_MESSAGE_SELF: u64 = 6006;

    // ========== Initialization ==========

    /// Initialize the messaging registry (called once during deployment)
    fun init(ctx: &mut TxContext) {
        let registry = messaging_types::new_registry(ctx);
        messaging_types::share_registry(registry);
    }

    // ========== Public API ==========

    /// Create a direct (1-on-1) conversation
    /// Creates a conversation between the sender and one other user
    public entry fun create_direct_conversation(
        registry: &mut ConversationRegistry,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        // Validate cannot message yourself
        assert!(sender != recipient, E_CANNOT_MESSAGE_SELF);

        // Create participant set
        let mut participants = vec_set::empty<address>();
        vec_set::insert(&mut participants, sender);
        vec_set::insert(&mut participants, recipient);

        let timestamp = clock::timestamp_ms(clock);

        // Create conversation
        let conversation = messaging_types::new_conversation(
            messaging_types::conversation_direct(),
            participants,
            sender,
            option::none(),
            timestamp,
            ctx,
        );

        let conversation_id = object::id(&conversation);

        // Update registry
        messaging_types::add_user_conversation(registry, sender, conversation_id, ctx);
        messaging_types::add_user_conversation(registry, recipient, conversation_id, ctx);
        messaging_types::increment_total_conversations(registry);

        // Emit event
        messaging_events::emit_conversation_created(
            conversation_id,
            messaging_types::conversation_direct(),
            sender,
            2,
            timestamp,
        );

        // Transfer conversation to sender (they manage it)
        messaging_types::transfer_conversation(conversation, sender);
    }

    /// Create a group conversation
    /// Creates a conversation with multiple participants
    public entry fun create_group_conversation(
        registry: &mut ConversationRegistry,
        participants_list: vector<address>,
        title: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        // Validate participants
        let len = std::vector::length(&participants_list);
        assert!(len >= 2, E_INVALID_PARTICIPANTS);

        // Create participant set and add creator
        let mut participants = vec_set::empty<address>();
        vec_set::insert(&mut participants, sender);

        // Add other participants
        let mut i = 0;
        while (i < len) {
            let participant = *std::vector::borrow(&participants_list, i);
            assert!(participant != sender, E_DUPLICATE_PARTICIPANTS);
            vec_set::insert(&mut participants, participant);
            i = i + 1;
        };

        let timestamp = clock::timestamp_ms(clock);
        let participant_count = vec_set::size(&participants);

        // Create conversation
        let conversation = messaging_types::new_conversation(
            messaging_types::conversation_group(),
            participants,
            sender,
            option::some(title),
            timestamp,
            ctx,
        );

        let conversation_id = object::id(&conversation);

        // Update registry for all participants
        messaging_types::add_user_conversation(registry, sender, conversation_id, ctx);
        i = 0;
        while (i < len) {
            let participant = *std::vector::borrow(&participants_list, i);
            messaging_types::add_user_conversation(registry, participant, conversation_id, ctx);
            i = i + 1;
        };
        messaging_types::increment_total_conversations(registry);

        // Emit event
        messaging_events::emit_conversation_created(
            conversation_id,
            messaging_types::conversation_group(),
            sender,
            participant_count,
            timestamp,
        );

        // Transfer conversation to sender
        messaging_types::transfer_conversation(conversation, sender);
    }

    /// Send a message in a conversation
    /// Message content is stored on Walrus, optionally encrypted with Seal
    public entry fun send_message(
        registry: &mut ConversationRegistry,
        conversation: &mut Conversation,
        walrus_blob_id: vector<u8>,
        seal_policy_id: Option<vector<u8>>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        // Validate sender is participant
        assert!(messaging_types::is_participant(conversation, sender), E_NOT_PARTICIPANT);

        // Validate conversation is active
        assert!(messaging_types::is_active(conversation), E_CONVERSATION_INACTIVE);

        // Validate Walrus blob ID
        walrus::validate_blob_id(&walrus_blob_id);

        // Validate Seal policy if provided
        if (option::is_some(&seal_policy_id)) {
            seal::validate_policy_id(option::borrow(&seal_policy_id));
        };

        let timestamp = clock::timestamp_ms(clock);
        let conversation_id = object::id(conversation);

        // Create message
        let message = messaging_types::new_message(
            conversation_id,
            sender,
            walrus_blob_id,
            seal_policy_id,
            timestamp,
            ctx,
        );

        let message_id = object::id(&message);

        // Update conversation
        messaging_types::update_last_message_at(conversation, timestamp);
        messaging_types::increment_message_count(conversation);

        // Update registry
        messaging_types::increment_total_messages(registry);

        // Emit event
        messaging_events::emit_message_sent(
            message_id,
            conversation_id,
            sender,
            timestamp,
        );

        // Transfer message to sender (they manage it)
        messaging_types::transfer_message(message, sender);
    }

    /// Mark a message as read
    public entry fun mark_as_read(
        message: &mut Message,
        ctx: &mut TxContext,
    ) {
        let reader = tx_context::sender(ctx);

        // Only mark as read if not already read by this user
        if (!messaging_types::is_read_by(message, reader)) {
            messaging_types::mark_message_read(message, reader);

            messaging_events::emit_message_read(
                object::id(message),
                messaging_types::message_conversation_id(message),
                reader,
            );
        };
    }

    /// Add participant to group conversation (creator only)
    public entry fun add_group_participant(
        registry: &mut ConversationRegistry,
        conversation: &mut Conversation,
        new_participant: address,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        // Only creator can add participants
        assert!(messaging_types::created_by(conversation) == sender, constants::e_not_program_owner());

        // Only for group conversations
        assert!(messaging_types::conversation_type(conversation) == messaging_types::conversation_group(), E_INVALID_PARTICIPANTS);

        // Add participant
        messaging_types::add_participant(conversation, new_participant);

        let conversation_id = object::id(conversation);
        messaging_types::add_user_conversation(registry, new_participant, conversation_id, ctx);

        // Emit event
        messaging_events::emit_participant_added(
            conversation_id,
            new_participant,
            clock::timestamp_ms(clock),
        );
    }

    /// Leave a conversation
    public entry fun leave_conversation(
        conversation: &mut Conversation,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        assert!(messaging_types::is_participant(conversation, sender), E_NOT_PARTICIPANT);

        // Remove from participants
        messaging_types::remove_participant(conversation, sender);

        // Emit event
        messaging_events::emit_participant_left(
            object::id(conversation),
            sender,
            clock::timestamp_ms(clock),
        );
    }

    /// Deactivate a conversation (creator only)
    public entry fun deactivate_conversation(
        conversation: &mut Conversation,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        // Only creator can deactivate
        assert!(messaging_types::created_by(conversation) == sender, constants::e_not_program_owner());

        messaging_types::deactivate_conversation(conversation);

        // Emit event
        messaging_events::emit_conversation_deactivated(
            object::id(conversation),
            clock::timestamp_ms(clock),
        );
    }

    // ========== Testing Functions ==========

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }
}
