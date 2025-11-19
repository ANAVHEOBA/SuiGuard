# SuiGuard Messaging & Forum Integration Guide

This guide provides comprehensive documentation for integrating the SuiGuard messaging and forum smart contract functions into your frontend application.

---

## Table of Contents

1. [Overview](#overview)
2. [Shared Objects](#shared-objects)
3. [Messaging System](#messaging-system)
   - [Data Structures](#messaging-data-structures)
   - [API Functions](#messaging-api-functions)
   - [Events](#messaging-events)
   - [TypeScript Integration](#messaging-typescript-integration)
4. [Forum System](#forum-system)
   - [Data Structures](#forum-data-structures)
   - [API Functions](#forum-api-functions)
   - [Events](#forum-events)
   - [TypeScript Integration](#forum-typescript-integration)
5. [Storage Integration](#storage-integration)
6. [Best Practices](#best-practices)

---

## Overview

SuiGuard provides two decentralized communication systems:

- **Messaging System**: Direct and group conversations between users with Walrus storage integration
- **Forum System**: Community discussion boards with moderation, voting, and reputation gates

Both systems leverage:
- **Walrus**: Decentralized blob storage for message/post content
- **Seal Protocol**: Optional end-to-end encryption for messages
- **On-chain Events**: Real-time updates for frontend sync

---

## Deployment Information

**Network:** Sui Devnet
**Package ID:** `0xe9aa6f069e2ee7692b67a7a76e1bc4034d9b21c38be22040bd5783e10d38d9e9`
**Deployment Date:** 2025-11-16
**Gas Used:** 0.174 SUI

> **Note**: This package was split from the main SuiGuard package due to 100 KB size limits. It contains all messaging and forum functionality.

---

## Shared Objects

These shared objects must be passed as arguments to transaction functions:

| Object | Object ID | Type |
|--------|-----------|------|
| **ConversationRegistry** | `0x186ad8881d34c449372d89602983c3098dc798ad6566ceb8236a33b2d6fd8219` | `suiguard_comms::messaging_types::ConversationRegistry` |
| **ForumRegistry** | `0x77edb656283f355a94d275887dcf0bd20d94d015e4c5683733b804ee567a6694` | `suiguard_comms::forum_types::ForumRegistry` |
| **VoteRecord** | `0x7f5d27300c7b8742b976123bea5e7d6b282edb4c6a789b78b773966244d2e5e9` | `suiguard_comms::forum_types::VoteRecord` |

---

## Messaging System

### Messaging Data Structures

#### ConversationRegistry (Shared Object)
```typescript
interface ConversationRegistry {
  id: string;
  user_conversations: Map<SuiAddress, Set<ObjectId>>; // User -> Conversation IDs
  total_conversations: number;
  total_messages: number;
}
```

#### Conversation (Owned Object)
```typescript
interface Conversation {
  id: ObjectId;
  conversation_type: number;      // 0 = Direct, 1 = Group
  participants: Set<SuiAddress>;
  created_by: SuiAddress;
  created_at: number;              // Unix timestamp (ms)
  last_message_at: number;
  message_count: number;
  title?: string;                  // For group chats
  is_active: boolean;
}

// Conversation Types
const CONVERSATION_DIRECT = 0;
const CONVERSATION_GROUP = 1;
```

#### Message (Owned Object)
```typescript
interface Message {
  id: ObjectId;
  conversation_id: ObjectId;
  sender: SuiAddress;
  walrus_blob_id: string;          // Walrus blob ID for content
  seal_policy_id?: string;         // Optional Seal encryption policy
  sent_at: number;                 // Unix timestamp (ms)
  status: number;                  // 0 = Sent, 1 = Read, 2 = Deleted
  read_by: Set<SuiAddress>;
}

// Message Status
const STATUS_SENT = 0;
const STATUS_READ = 1;
const STATUS_DELETED = 2;
```

### Messaging API Functions

#### 1. Create Direct Conversation
Creates a 1-on-1 conversation between two users.

```typescript
// Move Function
public entry fun create_direct_conversation(
  registry: &mut ConversationRegistry,
  recipient: address,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
import { Transaction } from '@mysten/sui/transactions';

const COMMS_PACKAGE_ID = "0xe9aa6f069e2ee7692b67a7a76e1bc4034d9b21c38be22040bd5783e10d38d9e9";

async function createDirectConversation(
  recipientAddress: string,
  conversationRegistryId: string,
  clockId: string = '0x6' // System clock
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::messaging_api::create_direct_conversation`,
    arguments: [
      tx.object(conversationRegistryId),
      tx.pure.address(recipientAddress),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 2. Create Group Conversation
Creates a group conversation with multiple participants.

```typescript
// Move Function
public entry fun create_group_conversation(
  registry: &mut ConversationRegistry,
  participants_list: vector<address>,
  title: vector<u8>,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function createGroupConversation(
  participantAddresses: string[],
  title: string,
  conversationRegistryId: string,
  clockId: string = '0x6'
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::messaging_api::create_group_conversation`,
    arguments: [
      tx.object(conversationRegistryId),
      tx.pure.vector('address', participantAddresses),
      tx.pure.string(title),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 3. Send Message
Send a message in a conversation (content stored on Walrus).

```typescript
// Move Function
public entry fun send_message(
  registry: &mut ConversationRegistry,
  conversation: &mut Conversation,
  walrus_blob_id: vector<u8>,
  seal_policy_id: Option<vector<u8>>,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function sendMessage(
  conversationId: string,
  messageContent: string,
  conversationRegistryId: string,
  sealPolicyId?: string,
  clockId: string = '0x6'
) {
  // 1. Upload content to Walrus
  const walrusBlobId = await uploadToWalrus(messageContent);

  // 2. Optionally encrypt with Seal
  const sealPolicy = sealPolicyId
    ? { vec: [Array.from(new TextEncoder().encode(sealPolicyId))] }
    : { vec: [] };

  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::messaging_api::send_message`,
    arguments: [
      tx.object(conversationRegistryId),
      tx.object(conversationId),
      tx.pure.string(walrusBlobId),
      tx.pure(sealPolicy, 'Option<vector<u8>>'),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 4. Mark Message as Read
Mark a message as read by the current user.

```typescript
// Move Function
public entry fun mark_as_read(
  message: &mut Message,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function markMessageAsRead(messageId: string) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::messaging_api::mark_as_read`,
    arguments: [tx.object(messageId)],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 5. Add Group Participant
Add a new participant to a group conversation (creator only).

```typescript
// Move Function
public entry fun add_group_participant(
  registry: &mut ConversationRegistry,
  conversation: &mut Conversation,
  new_participant: address,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function addGroupParticipant(
  conversationId: string,
  newParticipantAddress: string,
  conversationRegistryId: string,
  clockId: string = '0x6'
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::messaging_api::add_group_participant`,
    arguments: [
      tx.object(conversationRegistryId),
      tx.object(conversationId),
      tx.pure.address(newParticipantAddress),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 6. Leave Conversation
Remove yourself from a conversation.

```typescript
// Move Function
public entry fun leave_conversation(
  conversation: &mut Conversation,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function leaveConversation(
  conversationId: string,
  clockId: string = '0x6'
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::messaging_api::leave_conversation`,
    arguments: [
      tx.object(conversationId),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 7. Deactivate Conversation
Deactivate a conversation (creator only).

```typescript
// Move Function
public entry fun deactivate_conversation(
  conversation: &mut Conversation,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function deactivateConversation(
  conversationId: string,
  clockId: string = '0x6'
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::messaging_api::deactivate_conversation`,
    arguments: [
      tx.object(conversationId),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

### Messaging Events

Subscribe to these events for real-time updates:

#### ConversationCreated
```typescript
interface ConversationCreated {
  conversation_id: ObjectId;
  conversation_type: number;     // 0 = Direct, 1 = Group
  created_by: SuiAddress;
  participant_count: number;
  created_at: number;
}
```

#### MessageSent
```typescript
interface MessageSent {
  message_id: ObjectId;
  conversation_id: ObjectId;
  sender: SuiAddress;
  sent_at: number;
}
```

#### MessageRead
```typescript
interface MessageRead {
  message_id: ObjectId;
  conversation_id: ObjectId;
  reader: SuiAddress;
}
```

#### ParticipantAdded
```typescript
interface ParticipantAdded {
  conversation_id: ObjectId;
  participant: SuiAddress;
  added_at: number;
}
```

#### ParticipantLeft
```typescript
interface ParticipantLeft {
  conversation_id: ObjectId;
  participant: SuiAddress;
  left_at: number;
}
```

#### ConversationDeactivated
```typescript
interface ConversationDeactivated {
  conversation_id: ObjectId;
  deactivated_at: number;
}
```

### Messaging TypeScript Integration

**Event Listener Example:**
```typescript
import { SuiClient } from '@mysten/sui/client';

async function subscribeToMessagingEvents(conversationId: string) {
  const client = new SuiClient({ url: 'https://fullnode.devnet.sui.io' });

  const unsubscribe = await client.subscribeEvent({
    filter: {
      MoveEventModule: {
        package: COMMS_PACKAGE_ID,
        module: 'messaging_events',
      },
    },
    onMessage: (event) => {
      console.log('Messaging event:', event);

      switch (event.type) {
        case `${COMMS_PACKAGE_ID}::messaging_events::MessageSent`:
          handleNewMessage(event.parsedJson);
          break;
        case `${COMMS_PACKAGE_ID}::messaging_events::MessageRead`:
          handleMessageRead(event.parsedJson);
          break;
        // Handle other events...
      }
    },
  });

  return unsubscribe;
}
```

**Query User Conversations:**
```typescript
async function getUserConversations(userAddress: string) {
  const client = new SuiClient({ url: 'https://fullnode.devnet.sui.io' });

  // Get all Conversation objects owned by user
  const conversations = await client.getOwnedObjects({
    owner: userAddress,
    filter: {
      StructType: `${PACKAGE_ID}::messaging_types::Conversation`,
    },
    options: {
      showContent: true,
      showType: true,
    },
  });

  return conversations.data;
}
```

---

## Forum System

### Forum Data Structures

#### ForumRegistry (Shared Object)
```typescript
interface ForumRegistry {
  id: string;
  category_forums: Map<number, ObjectId>; // Category -> Forum ID
  total_forums: number;
  total_posts: number;
  total_replies: number;
}
```

#### Forum Categories
```typescript
const CATEGORY_EDUCATION = 0;
const CATEGORY_DISCLOSED_VULNS = 1;
const CATEGORY_PLATFORM_GOVERNANCE = 2;
const CATEGORY_TOOLS_RESOURCES = 3;
const CATEGORY_CAREERS = 4;
const CATEGORY_GENERAL = 5;
```

#### Forum (Shared Object)
```typescript
interface Forum {
  id: ObjectId;
  category: number;
  name: string;
  description: string;
  created_at: number;
  moderators: Set<SuiAddress>;
  min_reputation_to_post: number;
  post_count: number;
  last_post_at?: number;
}
```

#### Post (Owned Object)
```typescript
interface Post {
  id: ObjectId;
  forum_id: ObjectId;
  author: SuiAddress;
  title: string;
  walrus_blob_id: string;          // Content on Walrus
  created_at: number;
  updated_at: number;
  status: number;                  // 0 = Active, 1 = Locked, 2 = Deleted, 3 = Pinned
  reply_count: number;
  upvotes: number;
  tags: string[];
  last_reply_at?: number;
}

// Post Status
const STATUS_ACTIVE = 0;
const STATUS_LOCKED = 1;
const STATUS_DELETED = 2;
const STATUS_PINNED = 3;
```

#### Reply (Owned Object)
```typescript
interface Reply {
  id: ObjectId;
  post_id: ObjectId;
  author: SuiAddress;
  walrus_blob_id: string;
  created_at: number;
  updated_at: number;
  upvotes: number;
  parent_reply_id?: ObjectId;      // For nested replies
}
```

#### VoteRecord (Shared Object)
```typescript
interface VoteRecord {
  id: string;
  user_upvotes: Map<SuiAddress, Set<ObjectId>>; // User -> Content IDs upvoted
}
```

### Forum API Functions

#### 1. Create Forum
Create a new forum category (admin only).

```typescript
// Move Function
public entry fun create_forum(
  registry: &mut ForumRegistry,
  category: u8,
  name: vector<u8>,
  description: vector<u8>,
  min_reputation_to_post: u64,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function createForum(
  category: number,
  name: string,
  description: string,
  minReputation: number,
  forumRegistryId: string,
  clockId: string = '0x6'
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::forum_api::create_forum`,
    arguments: [
      tx.object(forumRegistryId),
      tx.pure.u8(category),
      tx.pure.string(name),
      tx.pure.string(description),
      tx.pure.u64(minReputation),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 2. Create Post
Create a new discussion post.

```typescript
// Move Function
public entry fun create_post(
  registry: &mut ForumRegistry,
  forum: &mut Forum,
  profile: &ResearcherProfile,
  title: vector<u8>,
  walrus_blob_id: vector<u8>,
  tags: vector<vector<u8>>,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function createPost(
  forumId: string,
  profileId: string,
  title: string,
  content: string,
  tags: string[],
  forumRegistryId: string,
  clockId: string = '0x6'
) {
  // 1. Upload content to Walrus
  const walrusBlobId = await uploadToWalrus(content);

  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::forum_api::create_post`,
    arguments: [
      tx.object(forumRegistryId),
      tx.object(forumId),
      tx.object(profileId),
      tx.pure.string(title),
      tx.pure.string(walrusBlobId),
      tx.pure.vector('string', tags),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 3. Reply to Post
Post a reply to a discussion.

```typescript
// Move Function
public entry fun reply_to_post(
  registry: &mut ForumRegistry,
  post: &mut Post,
  walrus_blob_id: vector<u8>,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function replyToPost(
  postId: string,
  replyContent: string,
  forumRegistryId: string,
  clockId: string = '0x6'
) {
  const walrusBlobId = await uploadToWalrus(replyContent);

  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::forum_api::reply_to_post`,
    arguments: [
      tx.object(forumRegistryId),
      tx.object(postId),
      tx.pure.string(walrusBlobId),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 4. Reply to Reply
Create a nested reply (reply to a reply).

```typescript
// Move Function
public entry fun reply_to_reply(
  registry: &mut ForumRegistry,
  post: &mut Post,
  parent_reply_id: ID,
  walrus_blob_id: vector<u8>,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function replyToReply(
  postId: string,
  parentReplyId: string,
  replyContent: string,
  forumRegistryId: string,
  clockId: string = '0x6'
) {
  const walrusBlobId = await uploadToWalrus(replyContent);

  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::forum_api::reply_to_reply`,
    arguments: [
      tx.object(forumRegistryId),
      tx.object(postId),
      tx.pure.id(parentReplyId),
      tx.pure.string(walrusBlobId),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 5. Upvote Post
Upvote a post (once per user).

```typescript
// Move Function
public entry fun upvote_post(
  votes: &mut VoteRecord,
  post: &mut Post,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function upvotePost(
  postId: string,
  voteRecordId: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::forum_api::upvote_post`,
    arguments: [
      tx.object(voteRecordId),
      tx.object(postId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 6. Remove Post Upvote
Remove your upvote from a post.

```typescript
// Move Function
public entry fun remove_post_upvote(
  votes: &mut VoteRecord,
  post: &mut Post,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function removePostUpvote(
  postId: string,
  voteRecordId: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::forum_api::remove_post_upvote`,
    arguments: [
      tx.object(voteRecordId),
      tx.object(postId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 7. Upvote Reply
Upvote a reply.

```typescript
// Move Function
public entry fun upvote_reply(
  votes: &mut VoteRecord,
  reply: &mut Reply,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function upvoteReply(
  replyId: string,
  voteRecordId: string
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::forum_api::upvote_reply`,
    arguments: [
      tx.object(voteRecordId),
      tx.object(replyId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 8. Lock Post (Moderator Only)
Lock a post to prevent new replies.

```typescript
// Move Function
public entry fun lock_post(
  forum: &Forum,
  post: &mut Post,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

**TypeScript Example:**
```typescript
async function lockPost(
  forumId: string,
  postId: string,
  clockId: string = '0x6'
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${COMMS_PACKAGE_ID}::forum_api::lock_post`,
    arguments: [
      tx.object(forumId),
      tx.object(postId),
      tx.object(clockId),
    ],
  });

  const result = await signAndExecuteTransaction({ transaction: tx });
  return result;
}
```

#### 9. Delete Post (Moderator Only)
Mark a post as deleted.

```typescript
// Move Function
public entry fun delete_post(
  forum: &Forum,
  post: &mut Post,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

#### 10. Pin Post (Moderator Only)
Pin a post to the top of the forum.

```typescript
// Move Function
public entry fun pin_post(
  forum: &Forum,
  post: &mut Post,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

#### 11. Add Moderator
Add a new moderator to a forum (existing moderators only).

```typescript
// Move Function
public entry fun add_moderator(
  forum: &mut Forum,
  new_moderator: address,
  clock: &Clock,
  ctx: &mut TxContext,
)
```

### Forum Events

#### ForumCreated
```typescript
interface ForumCreated {
  forum_id: ObjectId;
  category: number;
  created_at: number;
}
```

#### PostCreated
```typescript
interface PostCreated {
  post_id: ObjectId;
  forum_id: ObjectId;
  author: SuiAddress;
  created_at: number;
}
```

#### ReplyPosted
```typescript
interface ReplyPosted {
  reply_id: ObjectId;
  post_id: ObjectId;
  author: SuiAddress;
  parent_reply_id?: ObjectId;
  created_at: number;
}
```

#### Upvoted
```typescript
interface Upvoted {
  content_id: ObjectId;
  voter: SuiAddress;
  is_post: boolean;              // true = post, false = reply
}
```

#### UpvoteRemoved
```typescript
interface UpvoteRemoved {
  content_id: ObjectId;
  voter: SuiAddress;
  is_post: boolean;
}
```

#### PostLocked
```typescript
interface PostLocked {
  post_id: ObjectId;
  moderator: SuiAddress;
  timestamp: number;
}
```

#### PostDeleted
```typescript
interface PostDeleted {
  post_id: ObjectId;
  moderator: SuiAddress;
  timestamp: number;
}
```

#### PostPinned
```typescript
interface PostPinned {
  post_id: ObjectId;
  moderator: SuiAddress;
  timestamp: number;
}
```

#### ModeratorAdded
```typescript
interface ModeratorAdded {
  forum_id: ObjectId;
  moderator: SuiAddress;
  added_by: SuiAddress;
  timestamp: number;
}
```

#### ModeratorRemoved
```typescript
interface ModeratorRemoved {
  forum_id: ObjectId;
  moderator: SuiAddress;
  removed_by: SuiAddress;
  timestamp: number;
}
```

### Forum TypeScript Integration

**Event Listener Example:**
```typescript
async function subscribeToForumEvents(forumId: string) {
  const client = new SuiClient({ url: 'https://fullnode.devnet.sui.io' });

  const unsubscribe = await client.subscribeEvent({
    filter: {
      MoveEventModule: {
        package: COMMS_PACKAGE_ID,
        module: 'forum_events',
      },
    },
    onMessage: (event) => {
      console.log('Forum event:', event);

      switch (event.type) {
        case `${COMMS_PACKAGE_ID}::forum_events::PostCreated`:
          handleNewPost(event.parsedJson);
          break;
        case `${COMMS_PACKAGE_ID}::forum_events::ReplyPosted`:
          handleNewReply(event.parsedJson);
          break;
        case `${COMMS_PACKAGE_ID}::forum_events::Upvoted`:
          handleUpvote(event.parsedJson);
          break;
        // Handle other events...
      }
    },
  });

  return unsubscribe;
}
```

**Query Forum Posts:**
```typescript
async function getForumPosts(forumId: string) {
  const client = new SuiClient({ url: 'https://fullnode.devnet.sui.io' });

  // Query using dynamic fields or indexer
  const posts = await client.getDynamicFields({
    parentId: forumId,
  });

  // Or use Sui GraphQL indexer for more complex queries
  return posts;
}
```

---

## Storage Integration

### Walrus Integration

Both messaging and forum systems use Walrus for decentralized content storage.

**Upload to Walrus:**
```typescript
async function uploadToWalrus(content: string): Promise<string> {
  const walrusEndpoint = 'https://walrus-testnet-publisher.nodes.guru';

  const response = await fetch(`${walrusEndpoint}/v1/store`, {
    method: 'PUT',
    body: content,
  });

  const data = await response.json();
  return data.newlyCreated?.blobObject?.blobId || data.alreadyCertified?.blobId;
}
```

**Fetch from Walrus:**
```typescript
async function fetchFromWalrus(blobId: string): Promise<string> {
  const walrusAggregator = 'https://walrus-testnet-aggregator.nodes.guru';

  const response = await fetch(`${walrusAggregator}/v1/${blobId}`);
  return await response.text();
}
```

### Seal Protocol Integration (Optional)

For encrypted messaging:

```typescript
// Placeholder - integrate with Seal Protocol SDK when available
async function encryptWithSeal(content: string, recipients: string[]): Promise<string> {
  // Use Seal Protocol SDK to create encryption policy
  // Returns policy ID to store on-chain
  return 'seal_policy_id';
}

async function decryptWithSeal(blobId: string, policyId: string): Promise<string> {
  // Use Seal Protocol SDK to decrypt
  const encrypted = await fetchFromWalrus(blobId);
  // Decrypt using Seal
  return 'decrypted_content';
}
```

---

## Best Practices

### 1. Error Handling

```typescript
try {
  await sendMessage(conversationId, content, registryId);
} catch (error) {
  if (error.message.includes('6001')) {
    console.error('Not a participant in this conversation');
  } else if (error.message.includes('6002')) {
    console.error('Conversation is inactive');
  } else if (error.message.includes('6006')) {
    console.error('Cannot message yourself');
  }
  // Handle other errors...
}
```

### Error Codes Reference

**Messaging (6000-6999):**
- `6001`: E_NOT_PARTICIPANT
- `6002`: E_CONVERSATION_INACTIVE
- `6003`: E_INVALID_PARTICIPANTS
- `6004`: E_DUPLICATE_PARTICIPANTS
- `6005`: E_EMPTY_MESSAGE
- `6006`: E_CANNOT_MESSAGE_SELF

**Forum (7000-7999):**
- `7001`: E_INSUFFICIENT_REPUTATION
- `7002`: E_NOT_MODERATOR
- `7003`: E_POST_LOCKED
- `7004`: E_POST_DELETED
- `7005`: E_ALREADY_VOTED
- `7006`: E_NOT_VOTED
- `7007`: E_INVALID_TITLE
- `7008`: E_FORUM_EXISTS

### 2. Performance Optimization

**Use Object Batching:**
```typescript
// Fetch multiple messages in parallel
async function getConversationMessages(messageIds: string[]) {
  const client = new SuiClient({ url: 'https://fullnode.devnet.sui.io' });

  const messages = await Promise.all(
    messageIds.map(id => client.getObject({
      id,
      options: { showContent: true }
    }))
  );

  return messages;
}
```

**Cache Walrus Content:**
```typescript
const walrusCache = new Map<string, string>();

async function fetchFromWalrusCached(blobId: string): Promise<string> {
  if (walrusCache.has(blobId)) {
    return walrusCache.get(blobId)!;
  }

  const content = await fetchFromWalrus(blobId);
  walrusCache.set(blobId, content);
  return content;
}
```

### 3. Real-time Updates

**Use Event Subscriptions:**
```typescript
// Subscribe to conversation updates
function useConversationUpdates(conversationId: string) {
  useEffect(() => {
    const unsubscribe = subscribeToMessagingEvents(conversationId);
    return () => unsubscribe();
  }, [conversationId]);
}
```

### 4. Pagination

**Paginate Forum Posts:**
```typescript
async function getPaginatedPosts(
  forumId: string,
  cursor?: string,
  limit: number = 20
) {
  const client = new SuiClient({ url: 'https://fullnode.devnet.sui.io' });

  // Use Sui indexer or implement custom pagination logic
  // based on created_at timestamps
}
```

### 5. Security Considerations

- Always validate user permissions before showing moderation actions
- Encrypt sensitive messages using Seal Protocol
- Never expose private keys or signing logic in frontend
- Validate Walrus blob IDs before fetching content
- Implement rate limiting for post/message creation
- Check reputation requirements before allowing forum posts

---

## Support

For issues or questions:
- GitHub: [SuiGuard Issues](https://github.com/suiguard/suiguard/issues)
- Documentation: [Full Integration Guide](./FRONTEND_INTEGRATION.md)
- Walrus Docs: [Walrus Documentation](https://docs.walrus.site)
- Seal Docs: [Seal Protocol](https://seal.sui.io)

---

**Last Updated:** 2025-11-16
**Package Version:** See Move.toml
