/// Messaging Events
/// Event definitions for the messaging system
module suiguard::messaging_events {
    use sui::object::ID;
    use sui::event;

    /// Emitted when a new conversation is created
    public struct ConversationCreated has copy, drop {
        conversation_id: ID,
        conversation_type: u8,
        created_by: address,
        participant_count: u64,
        created_at: u64,
    }

    /// Emitted when a message is sent
    public struct MessageSent has copy, drop {
        message_id: ID,
        conversation_id: ID,
        sender: address,
        sent_at: u64,
    }

    /// Emitted when a message is marked as read
    public struct MessageRead has copy, drop {
        message_id: ID,
        conversation_id: ID,
        reader: address,
    }

    /// Emitted when a participant is added to a group
    public struct ParticipantAdded has copy, drop {
        conversation_id: ID,
        participant: address,
        added_at: u64,
    }

    /// Emitted when a participant leaves a conversation
    public struct ParticipantLeft has copy, drop {
        conversation_id: ID,
        participant: address,
        left_at: u64,
    }

    /// Emitted when a conversation is deactivated
    public struct ConversationDeactivated has copy, drop {
        conversation_id: ID,
        deactivated_at: u64,
    }

    // ========== Event Emitters (package-only) ==========

    public(package) fun emit_conversation_created(
        conversation_id: ID,
        conversation_type: u8,
        created_by: address,
        participant_count: u64,
        created_at: u64,
    ) {
        event::emit(ConversationCreated {
            conversation_id,
            conversation_type,
            created_by,
            participant_count,
            created_at,
        });
    }

    public(package) fun emit_message_sent(
        message_id: ID,
        conversation_id: ID,
        sender: address,
        sent_at: u64,
    ) {
        event::emit(MessageSent {
            message_id,
            conversation_id,
            sender,
            sent_at,
        });
    }

    public(package) fun emit_message_read(
        message_id: ID,
        conversation_id: ID,
        reader: address,
    ) {
        event::emit(MessageRead {
            message_id,
            conversation_id,
            reader,
        });
    }

    public(package) fun emit_participant_added(
        conversation_id: ID,
        participant: address,
        added_at: u64,
    ) {
        event::emit(ParticipantAdded {
            conversation_id,
            participant,
            added_at,
        });
    }

    public(package) fun emit_participant_left(
        conversation_id: ID,
        participant: address,
        left_at: u64,
    ) {
        event::emit(ParticipantLeft {
            conversation_id,
            participant,
            left_at,
        });
    }

    public(package) fun emit_conversation_deactivated(
        conversation_id: ID,
        deactivated_at: u64,
    ) {
        event::emit(ConversationDeactivated {
            conversation_id,
            deactivated_at,
        });
    }
}
