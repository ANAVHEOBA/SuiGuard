#[test_only]
module suiguard::forum_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use std::option;

    use suiguard::forum_api;
    use suiguard::forum_types::{Self, ForumRegistry, Forum, Post, Reply, VoteRecord};
    use suiguard::reputation_types::{Self, ResearcherProfile};

    // Test addresses
    const ALICE: address = @0xA11CE;
    const BOB: address = @0xB0B;
    const CHARLIE: address = @0xC11A51E;

    // Test Walrus blob IDs
    const TEST_BLOB_POST: vector<u8> = b"walrus://post123456789012345678901234567890";
    const TEST_BLOB_REPLY: vector<u8> = b"walrus://reply12345678901234567890123456789";

    // Helper to create a test researcher profile
    fun create_test_profile(scenario: &mut Scenario, researcher: address, clock: &Clock) {
        ts::next_tx(scenario, researcher);
        let profile = reputation_types::new_profile(researcher, sui::clock::timestamp_ms(clock), ts::ctx(scenario));
        sui::transfer::public_transfer(profile, researcher);
    }

    #[test]
    fun test_create_forum() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Initialize forum system
        {
            forum_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);

            forum_api::create_forum(
                &mut registry,
                forum_types::category_education(),
                b"Education & Learning",
                b"Share knowledge and learn together",
                0, // No reputation required
                &clock,
                ts::ctx(&mut scenario)
            );

            assert!(forum_types::total_forums(&registry) == 1, 0);
            assert!(forum_types::has_forum_category(&registry, forum_types::category_education()), 1);

            ts::return_shared(registry);
        };

        // Check forum was created
        ts::next_tx(&mut scenario, ALICE);
        {
            let forum = ts::take_shared<Forum>(&scenario);

            assert!(forum_types::category(&forum) == forum_types::category_education(), 0);
            assert!(*forum_types::name(&forum) == b"Education & Learning", 1);
            assert!(forum_types::is_moderator(&forum, ALICE), 2);
            assert!(forum_types::min_reputation_to_post(&forum) == 0, 3);

            ts::return_shared(forum);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_create_post() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Initialize forum system
        {
            forum_api::init_for_testing(ts::ctx(&mut scenario));
        };

        // Create forum
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            forum_api::create_forum(
                &mut registry,
                forum_types::category_general(),
                b"General Discussion",
                b"Talk about anything",
                0,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(registry);
        };

        // Create researcher profile for Alice
        create_test_profile(&mut scenario, ALICE, &clock);

        // Alice creates a post
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            let mut forum = ts::take_shared<Forum>(&scenario);
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            let mut tags = std::vector::empty<vector<u8>>();
            std::vector::push_back(&mut tags, b"introduction");
            std::vector::push_back(&mut tags, b"newbie");

            forum_api::create_post(
                &mut registry,
                &mut forum,
                &profile,
                b"Hello SuiGuard!",
                TEST_BLOB_POST,
                tags,
                &clock,
                ts::ctx(&mut scenario)
            );

            assert!(forum_types::post_count(&forum) == 1, 0);
            assert!(forum_types::total_posts(&registry) == 1, 1);

            ts::return_shared(registry);
            ts::return_shared(forum);
            ts::return_to_sender(&scenario, profile);
        };

        // Check post was created
        ts::next_tx(&mut scenario, ALICE);
        {
            let post = ts::take_from_sender<Post>(&scenario);

            assert!(forum_types::author(&post) == ALICE, 0);
            assert!(*forum_types::title(&post) == b"Hello SuiGuard!", 1);
            assert!(*forum_types::walrus_blob_id(&post) == TEST_BLOB_POST, 2);
            assert!(forum_types::reply_count(&post) == 0, 3);
            assert!(forum_types::upvotes(&post) == 0, 4);

            ts::return_to_sender(&scenario, post);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_reply_to_post() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Setup forum
        {
            forum_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            forum_api::create_forum(&mut registry, forum_types::category_general(), b"General", b"General", 0, &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
        };

        // Create profile for Alice
        create_test_profile(&mut scenario, ALICE, &clock);

        // Alice creates post
        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            let mut forum = ts::take_shared<Forum>(&scenario);
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            forum_api::create_post(
                &mut registry,
                &mut forum,
                &profile,
                b"Test Post",
                TEST_BLOB_POST,
                std::vector::empty(),
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
            ts::return_shared(forum);
            ts::return_to_sender(&scenario, profile);
        };

        // Bob replies to Alice's post
        ts::next_tx(&mut scenario, BOB);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            let mut post = ts::take_from_address<Post>(&scenario, ALICE);

            forum_api::reply_to_post(
                &mut registry,
                &mut post,
                TEST_BLOB_REPLY,
                &clock,
                ts::ctx(&mut scenario)
            );

            assert!(forum_types::reply_count(&post) == 1, 0);
            assert!(forum_types::total_replies(&registry) == 1, 1);

            ts::return_shared(registry);
            ts::return_to_address(ALICE, post);
        };

        // Check reply was created
        ts::next_tx(&mut scenario, BOB);
        {
            let reply = ts::take_from_sender<Reply>(&scenario);

            assert!(forum_types::reply_author(&reply) == BOB, 0);
            assert!(*forum_types::reply_walrus_blob_id(&reply) == TEST_BLOB_REPLY, 1);

            ts::return_to_sender(&scenario, reply);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_upvote_post() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Setup
        {
            forum_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            forum_api::create_forum(&mut registry, forum_types::category_general(), b"General", b"General", 0, &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
        };

        create_test_profile(&mut scenario, ALICE, &clock);

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            let mut forum = ts::take_shared<Forum>(&scenario);
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);

            forum_api::create_post(&mut registry, &mut forum, &profile, b"Great Post", TEST_BLOB_POST, std::vector::empty(), &clock, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_shared(forum);
            ts::return_to_sender(&scenario, profile);
        };

        // Bob upvotes Alice's post
        ts::next_tx(&mut scenario, BOB);
        {
            let mut votes = ts::take_shared<VoteRecord>(&scenario);
            let mut post = ts::take_from_address<Post>(&scenario, ALICE);

            assert!(forum_types::upvotes(&post) == 0, 0);

            forum_api::upvote_post(&mut votes, &mut post, ts::ctx(&mut scenario));

            assert!(forum_types::upvotes(&post) == 1, 1);

            ts::return_shared(votes);
            ts::return_to_address(ALICE, post);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 7005)] // E_ALREADY_VOTED
    fun test_cannot_double_upvote() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Setup
        {
            forum_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            forum_api::create_forum(&mut registry, forum_types::category_general(), b"General", b"General", 0, &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
        };

        create_test_profile(&mut scenario, ALICE, &clock);

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            let mut forum = ts::take_shared<Forum>(&scenario);
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            forum_api::create_post(&mut registry, &mut forum, &profile, b"Post", TEST_BLOB_POST, std::vector::empty(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
            ts::return_shared(forum);
            ts::return_to_sender(&scenario, profile);
        };

        // Bob upvotes once
        ts::next_tx(&mut scenario, BOB);
        {
            let mut votes = ts::take_shared<VoteRecord>(&scenario);
            let mut post = ts::take_from_address<Post>(&scenario, ALICE);
            forum_api::upvote_post(&mut votes, &mut post, ts::ctx(&mut scenario));
            ts::return_shared(votes);
            ts::return_to_address(ALICE, post);
        };

        // Bob tries to upvote again - should fail
        ts::next_tx(&mut scenario, BOB);
        {
            let mut votes = ts::take_shared<VoteRecord>(&scenario);
            let mut post = ts::take_from_address<Post>(&scenario, ALICE);
            forum_api::upvote_post(&mut votes, &mut post, ts::ctx(&mut scenario));
            ts::return_shared(votes);
            ts::return_to_address(ALICE, post);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_lock_post_by_moderator() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Setup
        {
            forum_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            forum_api::create_forum(&mut registry, forum_types::category_general(), b"General", b"General", 0, &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
        };

        create_test_profile(&mut scenario, ALICE, &clock);

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            let mut forum = ts::take_shared<Forum>(&scenario);
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            forum_api::create_post(&mut registry, &mut forum, &profile, b"Post", TEST_BLOB_POST, std::vector::empty(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
            ts::return_shared(forum);
            ts::return_to_sender(&scenario, profile);
        };

        // Alice (moderator) locks the post
        ts::next_tx(&mut scenario, ALICE);
        {
            let forum = ts::take_shared<Forum>(&scenario);
            let mut post = ts::take_from_address<Post>(&scenario, ALICE);

            assert!(forum_types::status(&post) == forum_types::status_active(), 0);

            forum_api::lock_post(&forum, &mut post, &clock, ts::ctx(&mut scenario));

            assert!(forum_types::status(&post) == forum_types::status_locked(), 1);

            ts::return_shared(forum);
            ts::return_to_address(ALICE, post);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_remove_upvote() {
        let mut scenario = ts::begin(ALICE);
        let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));

        // Setup
        {
            forum_api::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            forum_api::create_forum(&mut registry, forum_types::category_general(), b"General", b"General", 0, &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
        };

        create_test_profile(&mut scenario, ALICE, &clock);

        ts::next_tx(&mut scenario, ALICE);
        {
            let mut registry = ts::take_shared<ForumRegistry>(&scenario);
            let mut forum = ts::take_shared<Forum>(&scenario);
            let profile = ts::take_from_sender<ResearcherProfile>(&scenario);
            forum_api::create_post(&mut registry, &mut forum, &profile, b"Post", TEST_BLOB_POST, std::vector::empty(), &clock, ts::ctx(&mut scenario));
            ts::return_shared(registry);
            ts::return_shared(forum);
            ts::return_to_sender(&scenario, profile);
        };

        // Bob upvotes
        ts::next_tx(&mut scenario, BOB);
        {
            let mut votes = ts::take_shared<VoteRecord>(&scenario);
            let mut post = ts::take_from_address<Post>(&scenario, ALICE);
            forum_api::upvote_post(&mut votes, &mut post, ts::ctx(&mut scenario));
            assert!(forum_types::upvotes(&post) == 1, 0);
            ts::return_shared(votes);
            ts::return_to_address(ALICE, post);
        };

        // Bob removes upvote
        ts::next_tx(&mut scenario, BOB);
        {
            let mut votes = ts::take_shared<VoteRecord>(&scenario);
            let mut post = ts::take_from_address<Post>(&scenario, ALICE);
            forum_api::remove_post_upvote(&mut votes, &mut post, ts::ctx(&mut scenario));
            assert!(forum_types::upvotes(&post) == 0, 1);
            ts::return_shared(votes);
            ts::return_to_address(ALICE, post);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}
