#[test_only]
module suiguard::messaging_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use std::option;

    use suiguard::messaging_api;
    use suiguard::messaging_types::{Self, ConversationRegistry, Conversation, Message};

    // Test addresses
    const ALICE: address = @0xA11CE;
    const BOB: address = @0xB0B;
    const CHARLIE: address = @0xC11A51E;

    // Test Walrus blob IDs (fake for testing)
    const TEST_BLOB_1: vector<u8> = b"walrus://blob123456789012345678901234567890";
    const TEST_BLOB_2: vector<u8> = b"walrus://blob987654321098765432109876543210";

    #[test]
    fun test_create_direct_conversation() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Initialize messaging system
        {
            messaging_api::init_for_testing(ts::ctx(&mut scenario));
        };

        // Get registry
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);

            // Alice creates conversation with Bob
            messaging_api::create_direct_conversation(
                &mut registry,
                BOB,
                &clock,
                ts::ctx(&mut scenario)
            );

            assert!(messaging_types::total_conversations(&registry) == 1, 0);

            ts::return_shared(registry);
        };

        // Check conversation was created
        ts::next_tx(&mut scenario, ALICE);
        {
            let conversation = ts::take_from_sender<Conversation>(&scenario);

            assert!(messaging_types::is_participant(&conversation, ALICE), 1);
            assert!(messaging_types::is_participant(&conversation, BOB), 2);
            assert!(messaging_types::message_count(&conversation) == 0, 3);
            assert!(messaging_types::conversation_type(&conversation) == messaging_types::conversation_direct(), 4);

            ts::return_to_sender(&scenario, conversation);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_send_message() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Initialize and create conversation
        {
            messaging_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);
            messaging_api::create_direct_conversation(
                &mut registry,
                BOB,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(registry);
        };

        // Alice sends message to Bob
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);
            let mut conversation = ts::take_from_sender<Conversation>(&scenario);

            messaging_api::send_message(
                &mut registry,
                &mut conversation,
                TEST_BLOB_1,
                option::none(),
                &clock,
                ts::ctx(&mut scenario)
            );

            assert!(messaging_types::message_count(&conversation) == 1, 0);
            assert!(messaging_types::total_messages(&registry) == 1, 1);

            ts::return_shared(registry);
            ts::return_to_sender(&scenario, conversation);
        };

        // Check message was created
        ts::next_tx(&mut scenario, ALICE);
        {
            let message = ts::take_from_sender<Message>(&scenario);

            assert!(messaging_types::sender(&message) == ALICE, 2);
            assert!(*messaging_types::walrus_blob_id(&message) == TEST_BLOB_1, 3);
            assert!(messaging_types::is_read_by(&message, ALICE), 4);

            ts::return_to_sender(&scenario, message);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_create_group_conversation() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        {
            messaging_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);

            let mut participants = std::vector::empty<address>();
            std::vector::push_back(&mut participants, BOB);
            std::vector::push_back(&mut participants, CHARLIE);

            messaging_api::create_group_conversation(
                &mut registry,
                participants,
                b"Web3 Security Team",
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Check group conversation
        ts::next_tx(&mut scenario, ALICE);
        {
            let conversation = ts::take_from_sender<Conversation>(&scenario);

            assert!(messaging_types::conversation_type(&conversation) == messaging_types::conversation_group(), 0);
            assert!(messaging_types::is_participant(&conversation, ALICE), 1);
            assert!(messaging_types::is_participant(&conversation, BOB), 2);
            assert!(messaging_types::is_participant(&conversation, CHARLIE), 3);

            ts::return_to_sender(&scenario, conversation);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_mark_message_as_read() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Setup
        {
            messaging_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);
            messaging_api::create_direct_conversation(&mut registry, BOB, &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);
            let mut conversation = ts::take_from_sender<Conversation>(&scenario);
            messaging_api::send_message(&mut registry, &mut conversation, TEST_BLOB_1, option::none(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
            ts::return_to_sender(&scenario, conversation);
        };

        // Bob marks message as read
        ts::next_tx(&mut scenario, BOB);
        {
            let mut message = ts::take_from_address<Message>(&scenario, ALICE);

            assert!(!messaging_types::is_read_by(&message, BOB), 0);

            messaging_api::mark_as_read(&mut message, ts::ctx(&mut scenario));

            assert!(messaging_types::is_read_by(&message, BOB), 1);

            ts::return_to_address(ALICE, message);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 6006)] // E_CANNOT_MESSAGE_SELF
    fun test_cannot_message_self() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        {
            messaging_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);

            // Should fail - cannot message yourself
            messaging_api::create_direct_conversation(
                &mut registry,
                ALICE,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_leave_conversation() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        {
            messaging_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);

            let mut participants = std::vector::empty<address>();
            std::vector::push_back(&mut participants, BOB);
            std::vector::push_back(&mut participants, CHARLIE);

            messaging_api::create_group_conversation(
                &mut registry,
                participants,
                b"Test Group",
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Bob leaves the conversation
        ts::next_tx(&mut scenario, BOB);
        {
            let mut conversation = ts::take_from_address<Conversation>(&scenario, ALICE);

            assert!(messaging_types::is_participant(&conversation, BOB), 0);

            messaging_api::leave_conversation(&mut conversation, &clock, ts::ctx(&mut scenario));

            assert!(!messaging_types::is_participant(&conversation, BOB), 1);

            ts::return_to_address(ALICE, conversation);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_multiple_messages_in_conversation() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        {
            messaging_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);
            messaging_api::create_direct_conversation(&mut registry, BOB, &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
        };

        // Alice sends first message
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);
            let mut conversation = ts::take_from_sender<Conversation>(&scenario);
            messaging_api::send_message(&mut registry, &mut conversation, TEST_BLOB_1, option::none(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
            ts::return_to_sender(&scenario, conversation);
        };

        // Alice sends second message
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ConversationRegistry>(&scenario);
            let mut conversation = ts::take_from_sender<Conversation>(&scenario);
            messaging_api::send_message(&mut registry, &mut conversation, TEST_BLOB_2, option::none(), &clock, ts::ctx(&mut scenario));

            assert!(messaging_types::message_count(&conversation) == 2, 0);
            assert!(messaging_types::total_messages(&registry) == 2, 1);

            ts::return_shared(registry);
            ts::return_to_sender(&scenario, conversation);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}
