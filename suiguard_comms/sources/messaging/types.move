/// Messaging Data Models
/// Defines all structs and types for the decentralized messaging system
module suiguard::messaging_types {
    use std::option::{Self, Option};
    use sui::object::{Self, UID, ID};
    use sui::tx_context::TxContext;
    use sui::vec_set::{Self, VecSet};
    use sui::table::{Self, Table};

    /// Message status
    const STATUS_SENT: u8 = 0;
    const STATUS_READ: u8 = 1;
    const STATUS_DELETED: u8 = 2;

    /// Conversation types
    const CONVERSATION_DIRECT: u8 = 0;
    const CONVERSATION_GROUP: u8 = 1;

    /// Shared registry for all conversations
    public struct ConversationRegistry has key {
        id: UID,
        // Maps user address -> list of conversation IDs they're part of
        user_conversations: Table<address, VecSet<ID>>,
        total_conversations: u64,
        total_messages: u64,
    }

    /// A conversation between users (1-on-1 or group)
    public struct Conversation has key, store {
        id: UID,
        conversation_type: u8,
        participants: VecSet<address>,
        created_by: address,
        created_at: u64,
        last_message_at: u64,
        message_count: u64,
        // Metadata
        title: Option<vector<u8>>,              // For group chats
        // Access control
        is_active: bool,
    }

    /// Individual message within a conversation
    public struct Message has key, store {
        id: UID,
        conversation_id: ID,
        sender: address,
        // Message content stored on Walrus for decentralization
        walrus_blob_id: vector<u8>,
        // Optional: Seal policy for encrypted messages
        seal_policy_id: Option<vector<u8>>,
        sent_at: u64,
        status: u8,
        // Tracking who has read the message
        read_by: VecSet<address>,
    }

    // ========== Constructor Functions (package-only) ==========

    public(package) fun new_registry(ctx: &mut TxContext): ConversationRegistry {
        ConversationRegistry {
            id: object::new(ctx),
            user_conversations: table::new(ctx),
            total_conversations: 0,
            total_messages: 0,
        }
    }

    public(package) fun new_conversation(
        conversation_type: u8,
        participants: VecSet<address>,
        created_by: address,
        title: Option<vector<u8>>,
        created_at: u64,
        ctx: &mut TxContext,
    ): Conversation {
        Conversation {
            id: object::new(ctx),
            conversation_type,
            participants,
            created_by,
            created_at,
            last_message_at: created_at,
            message_count: 0,
            title,
            is_active: true,
        }
    }

    public(package) fun new_message(
        conversation_id: ID,
        sender: address,
        walrus_blob_id: vector<u8>,
        seal_policy_id: Option<vector<u8>>,
        sent_at: u64,
        ctx: &mut TxContext,
    ): Message {
        let mut read_by = vec_set::empty<address>();
        vec_set::insert(&mut read_by, sender); // Sender has "read" their own message

        Message {
            id: object::new(ctx),
            conversation_id,
            sender,
            walrus_blob_id,
            seal_policy_id,
            sent_at,
            status: STATUS_SENT,
            read_by,
        }
    }

    // ========== Registry Getters ==========

    public fun registry_id(registry: &ConversationRegistry): &UID {
        &registry.id
    }

    public fun total_conversations(registry: &ConversationRegistry): u64 {
        registry.total_conversations
    }

    public fun total_messages(registry: &ConversationRegistry): u64 {
        registry.total_messages
    }

    public fun user_conversation_ids(registry: &ConversationRegistry, user: address): &VecSet<ID> {
        table::borrow(&registry.user_conversations, user)
    }

    public fun has_conversations(registry: &ConversationRegistry, user: address): bool {
        table::contains(&registry.user_conversations, user)
    }

    // ========== Conversation Getters ==========

    public fun conversation_id(conv: &Conversation): &UID {
        &conv.id
    }

    public fun conversation_type(conv: &Conversation): u8 {
        conv.conversation_type
    }

    public fun participants(conv: &Conversation): &VecSet<address> {
        &conv.participants
    }

    public fun is_participant(conv: &Conversation, user: address): bool {
        vec_set::contains(&conv.participants, &user)
    }

    public fun created_by(conv: &Conversation): address {
        conv.created_by
    }

    public fun created_at(conv: &Conversation): u64 {
        conv.created_at
    }

    public fun last_message_at(conv: &Conversation): u64 {
        conv.last_message_at
    }

    public fun message_count(conv: &Conversation): u64 {
        conv.message_count
    }

    public fun title(conv: &Conversation): &Option<vector<u8>> {
        &conv.title
    }

    public fun is_active(conv: &Conversation): bool {
        conv.is_active
    }

    // ========== Message Getters ==========

    public fun message_id(msg: &Message): &UID {
        &msg.id
    }

    public fun message_conversation_id(msg: &Message): ID {
        msg.conversation_id
    }

    public fun sender(msg: &Message): address {
        msg.sender
    }

    public fun walrus_blob_id(msg: &Message): &vector<u8> {
        &msg.walrus_blob_id
    }

    public fun seal_policy_id(msg: &Message): &Option<vector<u8>> {
        &msg.seal_policy_id
    }

    public fun sent_at(msg: &Message): u64 {
        msg.sent_at
    }

    public fun status(msg: &Message): u8 {
        msg.status
    }

    public fun read_by(msg: &Message): &VecSet<address> {
        &msg.read_by
    }

    public fun is_read_by(msg: &Message, user: address): bool {
        vec_set::contains(&msg.read_by, &user)
    }

    // ========== Setters (package-only) ==========

    public(package) fun add_user_conversation(
        registry: &mut ConversationRegistry,
        user: address,
        conversation_id: ID,
        ctx: &mut TxContext,
    ) {
        if (!table::contains(&registry.user_conversations, user)) {
            table::add(&mut registry.user_conversations, user, vec_set::empty<ID>());
        };
        let user_convs = table::borrow_mut(&mut registry.user_conversations, user);
        vec_set::insert(user_convs, conversation_id);
    }

    public(package) fun increment_total_conversations(registry: &mut ConversationRegistry) {
        registry.total_conversations = registry.total_conversations + 1;
    }

    public(package) fun increment_total_messages(registry: &mut ConversationRegistry) {
        registry.total_messages = registry.total_messages + 1;
    }

    public(package) fun update_last_message_at(conv: &mut Conversation, timestamp: u64) {
        conv.last_message_at = timestamp;
    }

    public(package) fun increment_message_count(conv: &mut Conversation) {
        conv.message_count = conv.message_count + 1;
    }

    public(package) fun add_participant(conv: &mut Conversation, user: address) {
        vec_set::insert(&mut conv.participants, user);
    }

    public(package) fun remove_participant(conv: &mut Conversation, user: address) {
        vec_set::remove(&mut conv.participants, &user);
    }

    public(package) fun deactivate_conversation(conv: &mut Conversation) {
        conv.is_active = false;
    }

    public(package) fun mark_message_read(msg: &mut Message, reader: address) {
        vec_set::insert(&mut msg.read_by, reader);
        msg.status = STATUS_READ;
    }

    public(package) fun delete_message(msg: &mut Message) {
        msg.status = STATUS_DELETED;
    }

    // ========== Constants Accessors ==========

    public fun status_sent(): u8 { STATUS_SENT }
    public fun status_read(): u8 { STATUS_READ }
    public fun status_deleted(): u8 { STATUS_DELETED }

    public fun conversation_direct(): u8 { CONVERSATION_DIRECT }
    public fun conversation_group(): u8 { CONVERSATION_GROUP }

    // ========== Transfer Functions (package-only) ==========

    public(package) fun share_registry(registry: ConversationRegistry) {
        sui::transfer::share_object(registry);
    }

    public(package) fun transfer_conversation(conversation: Conversation, recipient: address) {
        sui::transfer::transfer(conversation, recipient);
    }

    public(package) fun transfer_message(message: Message, recipient: address) {
        sui::transfer::transfer(message, recipient);
    }
}
