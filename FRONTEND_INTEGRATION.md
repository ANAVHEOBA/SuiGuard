# SuiGuard Frontend Integration Guide

## Deployment Information

**Network:** Sui Testnet
**Package ID:** `0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802` (Version 1)
**Previous Package ID:** `0x6d0b40c211463251e6ef066bb45988472d2005424eb403c4e06f6c0986642b89` (Devnet - Deprecated)
**Last Updated:** 2025-11-23
**Total Gas Used:** ~0.71 SUI

## ⚠️ Important Updates

**Testnet Deployment (2025-11-23):**
- **Deployed to Testnet** (previously on Devnet)
- **All IDs have changed** - new package and object IDs
- **Network change** - Switch RPC to testnet
- Update ALL package and object IDs in your frontend

**Bounty Program Creation Requirements:**
- Minimum escrow amount: **0.1 SUI** (reduced from 10 SUI for testnet ease of use)
- Escrow must be sufficient to cover the **critical tier payout amount**
- New validation: `escrow >= max(0.1 SUI, critical_amount)`
- Error code `1001` (E_ESCROW_TOO_LOW) will be thrown if validation fails
- **For mainnet:** Increase minimum back to appropriate amount (e.g., 10+ SUI)
- See [Fee Requirements](#3-fee-requirements) for detailed information

---

## Shared Object IDs

⚠️ **Important:** Shared objects are created during package initialization. To obtain these object IDs on testnet:

1. **View the deployment transaction** on Sui Explorer to find created objects
2. **Check package initialization events**
3. **Make first contract call** - object IDs will be returned in transaction results

**How to find shared objects:**
```bash
# View package on explorer
https://testnet.suivision.xyz/package/0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802

# Or query created objects from deployment
sui client objects --json | jq '.[] | select(.data.content.type | contains("suiguard"))'
```

These shared objects must be passed as arguments to transaction functions:

| Object | Type | Object ID |
|--------|------|-----------|
| **BountyRegistry** | `suiguard::bounty_registry::ProgramRegistry` | *Obtain from init tx* |
| **TriageRegistry** | `suiguard::triage_types::TriageRegistry` | *Obtain from init tx* |
| **DuplicateRegistry** | `suiguard::duplicate_registry::DuplicateRegistry` | *Obtain from init tx* |
| **ArchiveRegistry** | `suiguard::archive_types::ArchiveRegistry` | *Obtain from init tx* |
| **Leaderboard** | `suiguard::statistics_types::Leaderboard` | *Obtain from init tx* |
| **NautilusRegistry** | `suiguard::nautilus_registry::EnclaveRegistry` | *Obtain from init tx* |
| **PlatformStatistics** | `suiguard::statistics_types::PlatformStatistics` | *Obtain from init tx* |

---

## Module Structure

### Core Modules

#### 1. **Bounty Management**
- `bounty_api` - Create and manage bug bounty programs
- `bounty_crud` - CRUD operations for bounty programs
- `bounty_registry` - Registry of all bounty programs
- `bounty_types` - Bounty data structures
- `bounty_validation` - Validation logic

#### 2. **Bug Report Management**
- `report_api` - Submit and manage bug reports
- `report_crud` - CRUD operations for reports
- `report_types` - Report data structures (refactored with dynamic fields)
- `report_response` - Project response handling
- `report_validation` - Validation logic
- `duplicate_registry` - Duplicate detection

#### 3. **Payout & Compensation**
- `payout_api` - Execute payouts to researchers
- `payout_types` - Payout data structures
- `split_api` - Revenue splitting for team submissions

#### 4. **Disclosure Management**
- `disclosure_api` - Manage vulnerability disclosure timelines

#### 5. **Triage System**
- `triage_api` - Create and manage triage votes
- `triage_voting` - Community voting on severity
- `triage_rewards` - Rewards for triage participants
- `triage_types` - Triage data structures

#### 6. **Reputation System**
- `reputation_api` - Track researcher reputation
- `reputation_types` - Reputation data structures

#### 7. **Statistics & Leaderboard**
- `statistics_api` - Platform statistics
- `statistics_types` - Statistics data structures

#### 8. **Integrations**
- `walrus` - Walrus decentralized storage validation
- `seal` - Seal Protocol integration
- `nautilus_api` - Nautilus wallet integration
- `nautilus_registry` - Nautilus program registry

#### 9. **Archive**
- `archive_api` - Archive closed reports
- `archive_types` - Archive data structures

---

## Key Data Structures

### BugReport (Refactored)

The BugReport struct has been refactored to use dynamic fields for better scalability:

**Core Fields (on-chain):**
```typescript
{
  id: ObjectId,
  program_id: ObjectId,
  researcher: SuiAddress,
  severity: number,        // 0-3 (Info, Low, Medium, High, Critical)
  category: number,        // 0-7 (See constants)
  walrus_blob_id: Uint8Array,
  seal_policy_id: Uint8Array | null,
  affected_targets: Uint8Array[],
  vulnerability_hash: Uint8Array,
  submission_fee: Balance,
  status: number,          // 0-6 (See constants)
  submitted_at: number,
  updated_at: number,
  duplicate_of: ObjectId | null,
  attestation_id: ObjectId | null
}
```

**Dynamic Fields (accessed via getters):**
- ProjectResponse (acknowledgment, clarification, dispute info)
- FixData (fix submission, verification)
- PayoutData (payout amount, execution status, splits)
- DisclosureData (disclosure timeline, public release)

### BountyProgram

```typescript
{
  id: ObjectId,
  project_name: string,
  project_owner: SuiAddress,
  description_blob_id: Uint8Array,
  reward_pool: Balance,
  severity_multipliers: {
    info: number,
    low: number,
    medium: number,
    high: number,
    critical: number
  },
  status: number,  // 0: Active, 1: Paused, 2: Closed
  created_at: number,
  updated_at: number,
  total_reports: number,
  total_paid: number
}
```

### TriageVote

```typescript
{
  id: ObjectId,
  report_id: ObjectId,
  vote_type: number,  // 0: Severity, 1: Duplicate
  votes: Map<SuiAddress, number>,
  total_votes: number,
  created_at: number,
  deadline: number,
  resolved: boolean,
  final_result: number | null
}
```

---

## Constants Reference

### Report Status
```typescript
const STATUS = {
  SUBMITTED: 0,
  UNDER_REVIEW: 1,
  ACCEPTED: 2,
  REJECTED: 3,
  DUPLICATE: 4,
  WITHDRAWN: 5,
  PAID: 6
}
```

### Severity Levels
```typescript
const SEVERITY = {
  INFO: 0,
  LOW: 1,
  MEDIUM: 2,
  HIGH: 3,
  CRITICAL: 4
}
```

### Vulnerability Categories
```typescript
const CATEGORY = {
  REENTRANCY: 0,
  OVERFLOW: 1,
  LOGIC_ERROR: 2,
  ACCESS_CONTROL: 3,
  PRICE_MANIPULATION: 4,
  DENIAL_OF_SERVICE: 5,
  FRONT_RUNNING: 6,
  OTHER: 7
}
```

### Bounty Status
```typescript
const BOUNTY_STATUS = {
  ACTIVE: 0,
  PAUSED: 1,
  CLOSED: 2
}
```

---

## Entry Point Functions

### 1. Bounty Program Management

#### Create Bounty Program
```typescript
function createBountyProgram(
  registry: &mut ProgramRegistry,
  name: string,
  description: string,
  escrow: Coin<SUI>,
  critical_amount: u64,
  high_amount: u64,
  medium_amount: u64,
  low_amount: u64,
  informational_amount: u64,
  walrus_blob_id: Uint8Array,
  duration_days: u64,
  ctx: TxContext
): void

// Module: suiguard::bounty_api
// Function: create_bounty_program

// Requirements:
// - escrow >= 10 SUI (10_000_000_000 MIST)
// - escrow >= critical_amount
// - critical_amount > high_amount > medium_amount > low_amount
// - All amounts >= 1 SUI (1_000_000_000 MIST)
// - duration_days: 30-365 days
```

#### Update Bounty Program
```typescript
function updateBountyRewards(
  registry: BountyRegistry,
  program_id: ObjectId,
  info_multiplier: number,
  low_multiplier: number,
  medium_multiplier: number,
  high_multiplier: number,
  critical_multiplier: number,
  ctx: TxContext
): void

// Module: suiguard::bounty_api
// Function: update_bounty_rewards
```

#### Add Funds to Bounty
```typescript
function addFundsToBounty(
  registry: BountyRegistry,
  program_id: ObjectId,
  payment: Coin<SUI>,
  ctx: TxContext
): void

// Module: suiguard::bounty_api
// Function: add_funds_to_bounty
```

### 2. Bug Report Submission

#### Submit Bug Report
```typescript
function submitBugReport(
  registry: BountyRegistry,
  program_id: ObjectId,
  severity: number,
  category: number,
  walrus_blob_id: Uint8Array,
  seal_policy_id: Uint8Array | null,
  affected_targets: Uint8Array[],
  submission_fee: Coin<SUI>,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::report_api
// Function: submit_bug_report
```

#### Withdraw Report
```typescript
function withdrawReport(
  report_id: ObjectId,
  ctx: TxContext
): void

// Module: suiguard::report_api
// Function: withdraw_report
```

### 3. Project Response Actions

#### Acknowledge Report
```typescript
function acknowledgeReport(
  registry: BountyRegistry,
  program_id: ObjectId,
  report_id: ObjectId,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::report_response
// Function: acknowledge_report
```

#### Request Clarification
```typescript
function requestClarification(
  registry: BountyRegistry,
  program_id: ObjectId,
  report_id: ObjectId,
  message_blob_id: Uint8Array,
  ctx: TxContext
): void

// Module: suiguard::report_response
// Function: request_clarification
```

#### Accept Report
```typescript
function acceptReport(
  registry: BountyRegistry,
  program_id: ObjectId,
  report_id: ObjectId,
  payout_amount: number,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::report_response
// Function: accept_report
```

#### Reject Report
```typescript
function rejectReport(
  registry: BountyRegistry,
  program_id: ObjectId,
  report_id: ObjectId,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::report_response
// Function: reject_report
```

### 4. Triage & Voting

#### Create Severity Vote
```typescript
function createTriageVote(
  registry: TriageRegistry,
  report_id: ObjectId,
  proposed_severity: number,
  vote_duration_days: number,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::triage_api
// Function: create_triage_vote
```

#### Cast Vote
```typescript
function castVote(
  registry: TriageRegistry,
  vote_id: ObjectId,
  vote_value: number,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::triage_api
// Function: cast_vote
```

#### Finalize Vote
```typescript
function finalizeVote(
  registry: TriageRegistry,
  vote_id: ObjectId,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::triage_api
// Function: finalize_vote
```

### 5. Payout Execution

#### Execute Payout
```typescript
function executePayout(
  registry: BountyRegistry,
  program_id: ObjectId,
  report_id: ObjectId,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::payout_api
// Function: execute_payout
```

#### Claim Payout
```typescript
function claimPayout(
  report_id: ObjectId,
  ctx: TxContext
): void

// Module: suiguard::payout_api
// Function: claim_payout
```

### 6. Disclosure Management

#### Request Early Disclosure
```typescript
function requestEarlyDisclosure(
  registry: BountyRegistry,
  program_id: ObjectId,
  report_id: ObjectId,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::disclosure_api
// Function: request_early_disclosure
```

#### Approve Early Disclosure
```typescript
function approveEarlyDisclosure(
  registry: BountyRegistry,
  program_id: ObjectId,
  report_id: ObjectId,
  public_seal_policy: Uint8Array,
  ctx: TxContext
): void

// Module: suiguard::disclosure_api
// Function: approve_early_disclosure
```

#### Publish Disclosure
```typescript
function publishDisclosure(
  registry: BountyRegistry,
  report_id: ObjectId,
  public_seal_policy: Uint8Array,
  clock: Clock,
  ctx: TxContext
): void

// Module: suiguard::disclosure_api
// Function: publish_disclosure
```

---

## Events

All events are emitted during transaction execution and can be subscribed to via Sui RPC.

### Bounty Events (`bounty_events`)

```typescript
// Emitted when a new bounty program is created
event BountyProgramCreated {
  program_id: ObjectId,
  project_name: string,
  owner: SuiAddress,
  initial_pool: number
}

// Emitted when bounty rewards are updated
event BountyRewardsUpdated {
  program_id: ObjectId,
  info_multiplier: number,
  low_multiplier: number,
  medium_multiplier: number,
  high_multiplier: number,
  critical_multiplier: number
}

// Emitted when funds are added to a bounty
event BountyFunded {
  program_id: ObjectId,
  amount: number,
  new_total: number
}

// Emitted when bounty status changes
event BountyStatusChanged {
  program_id: ObjectId,
  old_status: number,
  new_status: number
}
```

### Report Events (`report_events`)

```typescript
// Emitted when a bug report is submitted
event BugReportSubmitted {
  report_id: ObjectId,
  program_id: ObjectId,
  researcher: SuiAddress,
  severity: number,
  category: number
}

// Emitted when report status changes
event ReportStatusChanged {
  report_id: ObjectId,
  old_status: number,
  new_status: number
}

// Emitted when a report is acknowledged
event ReportAcknowledged {
  report_id: ObjectId,
  program_id: ObjectId,
  acknowledged_at: number
}

// Emitted when clarification is requested
event ClarificationRequested {
  report_id: ObjectId,
  program_id: ObjectId,
  message_blob_id: Uint8Array
}

// Emitted when a report is accepted
event ReportAccepted {
  report_id: ObjectId,
  program_id: ObjectId,
  payout_amount: number
}

// Emitted when a report is rejected
event ReportRejected {
  report_id: ObjectId,
  program_id: ObjectId
}

// Emitted when a report is marked as duplicate
event ReportMarkedDuplicate {
  report_id: ObjectId,
  original_report_id: ObjectId
}
```

### Payout Events (`payout_events`)

```typescript
// Emitted when payout is executed
event PayoutExecuted {
  report_id: ObjectId,
  program_id: ObjectId,
  researcher: SuiAddress,
  amount: number
}

// Emitted when payout is claimed by researcher
event PayoutClaimed {
  report_id: ObjectId,
  researcher: SuiAddress,
  amount: number
}

// Emitted when split proposal is created
event SplitProposalCreated {
  report_id: ObjectId,
  proposal_id: ObjectId,
  total_recipients: number
}
```

### Triage Events (`triage_events`)

```typescript
// Emitted when triage vote is created
event TriageVoteCreated {
  vote_id: ObjectId,
  report_id: ObjectId,
  vote_type: number,
  creator: SuiAddress,
  deadline: number
}

// Emitted when a vote is cast
event VoteCast {
  vote_id: ObjectId,
  voter: SuiAddress,
  vote_value: number
}

// Emitted when voting concludes
event VoteFinalized {
  vote_id: ObjectId,
  final_result: number,
  total_votes: number
}
```

### Disclosure Events (`disclosure_events`)

```typescript
// Emitted when early disclosure is requested
event EarlyDisclosureRequested {
  report_id: ObjectId,
  researcher: SuiAddress,
  requested_at: number
}

// Emitted when early disclosure is approved
event EarlyDisclosureApproved {
  report_id: ObjectId,
  program_id: ObjectId
}

// Emitted when vulnerability is publicly disclosed
event VulnerabilityDisclosed {
  report_id: ObjectId,
  disclosed_at: number,
  public_seal_policy: Uint8Array
}
```

---

## Error Codes

### Common Errors
```typescript
const ERRORS = {
  // Bounty Errors (1000-1999)
  E_ESCROW_TOO_LOW: 1001,
  E_INVALID_TIER_ORDER: 1002,
  E_EMPTY_NAME: 1003,
  E_NAME_TOO_LONG: 1004,
  E_PAYOUT_TOO_LOW: 1005,
  E_NOT_PROGRAM_OWNER: 1006,
  E_PROGRAM_NOT_ACTIVE: 1007,
  E_PROGRAM_EXPIRED: 1008,
  E_INSUFFICIENT_ESCROW: 1009,
  E_INVALID_EXPIRY: 1010,

  // Report Errors (2000-2999)
  E_REPORT_NOT_FOUND: 2001,
  E_INVALID_BLOB_ID: 2002,
  E_DUPLICATE_REPORT: 2003,
  E_INVALID_SEVERITY: 2010,
  E_INVALID_CATEGORY: 2011,
  E_FEE_TOO_LOW: 2012,

  // Triage Errors (3000-3999)
  E_INSUFFICIENT_STAKE: 3001,
  E_VOTING_ENDED: 3002,
  E_TRIAGE_NOT_FINALIZED: 3003,

  // Reputation Errors (4000-4999)
  E_REPUTATION_NOT_FOUND: 4001,

  // Integration Errors (5000-5999)
  E_INVALID_ATTESTATION: 5001,
  E_INVALID_SEAL_POLICY: 5002,
  E_INVALID_WALRUS_CONFIG: 5003,
  E_INVALID_TOTAL_PERCENTAGE: 5000,

  // Messaging Errors (6000-6999)
  E_NOT_PARTICIPANT: 6001,
  E_CONVERSATION_INACTIVE: 6002,
  E_INVALID_PARTICIPANTS: 6003,
  E_DUPLICATE_PARTICIPANTS: 6004,
  E_EMPTY_MESSAGE: 6005,
  E_CANNOT_MESSAGE_SELF: 6006,

  // Forum Errors (7000-7999)
  E_INSUFFICIENT_REPUTATION: 7001,
  E_NOT_MODERATOR: 7002,
  E_POST_LOCKED: 7003,
  E_POST_DELETED: 7004,
  E_ALREADY_VOTED: 7005,
  E_NOT_VOTED: 7006,
  E_INVALID_TITLE: 7007,
  E_FORUM_EXISTS: 7008,

  // Disclosure Errors (9000-9999)
  E_NOT_RESEARCHER: 9000,
  E_NOT_DISCLOSED: 9001,
  E_ALREADY_DISCLOSED: 9002,
  E_DEADLINE_NOT_REACHED: 9003,
  E_FIX_NOT_SUBMITTED: 9004,

  // Archive Errors (10000-10999)
  E_NOT_DISCLOSED_ARCHIVE: 10000,

  // Triage Voting Errors (100-199)
  E_VOTING_ENDED_TRIAGE: 100,
  E_INSUFFICIENT_STAKE_TRIAGE: 101,
  E_NO_VOTES_CAST: 102,
  E_ALREADY_VOTED_TRIAGE: 103,
  E_INVALID_SEVERITY_VOTE: 104
}
```

---

## Integration Examples

### Example 1: Creating a Bounty Program

```typescript
import { TransactionBlock } from '@mysten/sui.js';

const tx = new TransactionBlock();

const PACKAGE_ID = "0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802";
const BOUNTY_REGISTRY = "OBTAIN_FROM_INIT_TX"; // See Shared Objects section

// Create coin for initial funding
// IMPORTANT: Escrow must be at least 0.1 SUI (testnet) AND must cover the critical tier payout
// In this example: critical tier = 2 SUI (base 0.1 SUI * 20x multiplier)
// So we need minimum 2 SUI escrow
const [coin] = tx.splitCoins(tx.gas, [tx.pure(2_000_000_000)]); // 2 SUI

tx.moveCall({
  target: `${PACKAGE_ID}::bounty_api::create_bounty_program`,
  arguments: [
    tx.object(BOUNTY_REGISTRY),
    tx.pure("My DeFi Project"),
    tx.pure(Array.from(walrusBlobId)),  // Uint8Array of description blob ID
    coin,
    tx.pure(100_000_000),   // critical_amount: 0.1 SUI (will be * 20x = 2 SUI)
    tx.pure(1_000_000_000),     // high_amount: 1 SUI
    tx.pure(1_000_000_000),     // medium_amount: 1 SUI
    tx.pure(1_000_000_000),     // low_amount: 1 SUI
    tx.pure(1_000_000_000),      // informational_amount: 1 SUI
    tx.pure(Array.from(walrusBlobId)),  // Walrus blob ID for details
    tx.pure(90),  // duration_days: 90 days
  ],
});

const result = await signer.signAndExecuteTransactionBlock({
  transactionBlock: tx,
});
```

**Helper Function for Escrow Validation:**
```typescript
const MIN_ESCROW_SUI = 0.1; // 0.1 SUI minimum (TESTNET - use higher for mainnet!)
const MIN_PAYOUT_SUI = 1;  // 1 SUI minimum per tier
const SUI_TO_MIST = 1_000_000_000;

function validateBountyCreation(
  escrowSUI: number,
  criticalSUI: number,
  highSUI: number,
  mediumSUI: number,
  lowSUI: number,
  informationalSUI: number
): { valid: boolean; error?: string } {
  // Check minimum escrow
  if (escrowSUI < MIN_ESCROW_SUI) {
    return { valid: false, error: `Escrow must be at least ${MIN_ESCROW_SUI} SUI` };
  }

  // Check escrow covers critical tier
  if (escrowSUI < criticalSUI) {
    return {
      valid: false,
      error: `Escrow (${escrowSUI} SUI) must be >= critical tier (${criticalSUI} SUI)`
    };
  }

  // Check minimum payout amounts
  const tiers = [criticalSUI, highSUI, mediumSUI, lowSUI, informationalSUI];
  for (const tier of tiers) {
    if (tier < MIN_PAYOUT_SUI) {
      return { valid: false, error: `All tiers must be at least ${MIN_PAYOUT_SUI} SUI` };
    }
  }

  // Check tier ordering
  if (!(criticalSUI > highSUI && highSUI > mediumSUI && mediumSUI > lowSUI)) {
    return {
      valid: false,
      error: 'Tier order must be: Critical > High > Medium > Low'
    };
  }

  return { valid: true };
}

// Example usage:
const validation = validateBountyCreation(2, 0.1, 1, 1, 1, 1);
if (!validation.valid) {
  console.error('Validation failed:', validation.error);
  // Handle error - don't submit transaction
} else {
  // Proceed with transaction
}
```

### Example 2: Submitting a Bug Report

```typescript
import { TransactionBlock } from '@mysten/sui.js';

const tx = new TransactionBlock();

const PACKAGE_ID = "0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802";
const BOUNTY_REGISTRY = "OBTAIN_FROM_INIT_TX"; // See Shared Objects section
const CLOCK = "0x6"; // Sui system clock

// Create submission fee coin (0.1 SUI)
const [feeCoin] = tx.splitCoins(tx.gas, [tx.pure(100_000_000)]);

// Prepare affected targets
const affectedTargets = [
  Array.from(new TextEncoder().encode("0x123::module::function")),
  Array.from(new TextEncoder().encode("0x456::another::target"))
];

tx.moveCall({
  target: `${PACKAGE_ID}::report_api::submit_bug_report`,
  arguments: [
    tx.object(BOUNTY_REGISTRY),
    tx.pure(programId),  // ObjectId of the bounty program
    tx.pure(4),          // severity: CRITICAL
    tx.pure(3),          // category: ACCESS_CONTROL
    tx.pure(Array.from(walrusBlobId)),  // report content on Walrus
    tx.pure(Array.from(sealPolicyId), 'vector<u8>'),  // optional Seal policy
    tx.pure(affectedTargets, 'vector<vector<u8>>'),
    feeCoin,
    tx.object(CLOCK),
  ],
});

const result = await signer.signAndExecuteTransactionBlock({
  transactionBlock: tx,
});
```

### Example 3: Accepting a Report and Setting Payout

```typescript
import { TransactionBlock } from '@mysten/sui.js';

const tx = new TransactionBlock();

const PACKAGE_ID = "0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802";
const BOUNTY_REGISTRY = "OBTAIN_FROM_INIT_TX"; // See Shared Objects section
const CLOCK = "0x6";

tx.moveCall({
  target: `${PACKAGE_ID}::report_response::accept_report`,
  arguments: [
    tx.object(BOUNTY_REGISTRY),
    tx.pure(programId),  // ObjectId of bounty program
    tx.pure(reportId),   // ObjectId of the report
    tx.pure(5_000_000_000),  // payout: 5 SUI
    tx.object(CLOCK),
  ],
});

const result = await signer.signAndExecuteTransactionBlock({
  transactionBlock: tx,
});
```

### Example 4: Executing Payout

```typescript
import { TransactionBlock } from '@mysten/sui.js';

const tx = new TransactionBlock();

const PACKAGE_ID = "0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802";
const BOUNTY_REGISTRY = "OBTAIN_FROM_INIT_TX"; // See Shared Objects section
const CLOCK = "0x6";

tx.moveCall({
  target: `${PACKAGE_ID}::payout_api::execute_payout`,
  arguments: [
    tx.object(BOUNTY_REGISTRY),
    tx.pure(programId),
    tx.pure(reportId),
    tx.object(CLOCK),
  ],
});

const result = await signer.signAndExecuteTransactionBlock({
  transactionBlock: tx,
});
```

### Example 5: Subscribing to Events

```typescript
import { SuiClient } from '@mysten/sui.js/client';

const client = new SuiClient({ url: 'https://fullnode.devnet.sui.io' });

// Subscribe to all BugReportSubmitted events
const unsubscribe = await client.subscribeEvent({
  filter: {
    MoveEventType: `${PACKAGE_ID}::report_events::BugReportSubmitted`
  },
  onMessage: (event) => {
    console.log('New bug report:', event.parsedJson);
    // event.parsedJson contains:
    // {
    //   report_id: string,
    //   program_id: string,
    //   researcher: string,
    //   severity: number,
    //   category: number
    // }
  }
});

// Unsubscribe when done
// unsubscribe();
```

### Example 6: Querying Bounty Programs

```typescript
import { SuiClient } from '@mysten/sui.js/client';

const client = new SuiClient({ url: 'https://fullnode.testnet.sui.io' });

// Get all bounty programs from registry
const BOUNTY_REGISTRY = "OBTAIN_FROM_INIT_TX"; // See Shared Objects section
const bountyRegistry = await client.getObject({
  id: BOUNTY_REGISTRY,
  options: {
    showContent: true,
    showType: true,
  }
});

// Query dynamic fields to get program list
const dynamicFields = await client.getDynamicFields({
  parentId: bountyRegistry.data.objectId,
});

// Fetch individual programs
for (const field of dynamicFields.data) {
  const program = await client.getDynamicFieldObject({
    parentId: bountyRegistry.data.objectId,
    name: field.name,
  });
  console.log('Bounty Program:', program);
}
```

### Example 7: Reading Report Data

```typescript
import { SuiClient } from '@mysten/sui.js/client';

const client = new SuiClient({ url: 'https://fullnode.testnet.sui.io' });

// Get bug report object
const report = await client.getObject({
  id: reportId,
  options: {
    showContent: true,
    showType: true,
  }
});

// Access core fields
const reportData = report.data.content.fields;
console.log('Report Status:', reportData.status);
console.log('Severity:', reportData.severity);
console.log('Researcher:', reportData.researcher);

// Access dynamic fields (ProjectResponse, FixData, PayoutData, DisclosureData)
const dynamicFields = await client.getDynamicFields({
  parentId: reportId,
});

for (const field of dynamicFields.data) {
  const fieldData = await client.getDynamicFieldObject({
    parentId: reportId,
    name: field.name,
  });
  console.log(`Dynamic Field ${field.name.value}:`, fieldData);
}
```

---

## Security Considerations

### 1. Authorization
- Only bounty program owners can accept/reject reports
- Only researchers can withdraw their own reports
- Only project owners can manage bounty settings

### 2. Validation
- Walrus blob IDs must be 32-66 bytes
- Seal policy IDs must be 32-66 bytes (when provided)
- Severity must be 0-4
- Category must be 0-7
- Affected targets cannot be empty

### 3. Fee Requirements

**Bounty Program Creation (Testnet):**
- Minimum escrow: **0.1 SUI** (100_000_000 MIST) - **reduced for testnet ease of use**
- Escrow must be **greater than or equal to the critical tier payout amount**
  - Example: If critical tier is set to 0.1 SUI, escrow must be at least 0.1 SUI
  - Example: If critical tier is set to 5 SUI, escrow must be at least 5 SUI
- Minimum payout amount per tier: **1 SUI** (1_000_000_000 MIST)
- Tier order validation: Critical > High > Medium > Low
- ⚠️ **For Mainnet:** Increase minimum escrow to appropriate amount (e.g., 10+ SUI)

**Bug Report Submission:**
- Submission fee: **0.1 SUI** (100_000_000 MIST) - returned if report is accepted
- Sufficient funds must be in bounty pool for payouts

### 4. Disclosure Timeline
- Default 90-day disclosure deadline from submission
- Early disclosure requires project approval
- Public disclosure only after deadline or approval

---

## Walrus Storage Integration

SuiGuard uses Walrus for decentralized storage of bug report content.

### Storing Report Content on Walrus

```typescript
// 1. Upload report content to Walrus
const walrusResponse = await fetch('https://publisher.walrus-testnet.walrus.space/v1/store', {
  method: 'PUT',
  body: JSON.stringify({
    title: "Critical Access Control Bug",
    description: "Detailed vulnerability description...",
    proof_of_concept: "PoC code...",
    impact: "Attacker can drain funds...",
    remediation: "Recommended fix..."
  })
});

const { blobId } = await walrusResponse.json();

// 2. Convert blob ID to Uint8Array
const blobIdBytes = new TextEncoder().encode(blobId);

// 3. Submit report with Walrus blob ID
const tx = new TransactionBlock();
const [feeCoin] = tx.splitCoins(tx.gas, [tx.pure(100_000_000)]);

tx.moveCall({
  target: `${PACKAGE_ID}::report_api::submit_bug_report`,
  arguments: [
    tx.object(BOUNTY_REGISTRY),
    tx.pure(programId),
    tx.pure(severity),
    tx.pure(category),
    tx.pure(Array.from(blobIdBytes)),  // Walrus blob ID
    // ... other arguments
  ],
});
```

### Retrieving Report Content from Walrus

```typescript
// 1. Get report from Sui
const report = await client.getObject({
  id: reportId,
  options: { showContent: true }
});

// 2. Extract Walrus blob ID
const blobIdBytes = report.data.content.fields.walrus_blob_id;
const blobId = new TextDecoder().decode(new Uint8Array(blobIdBytes));

// 3. Fetch content from Walrus
const content = await fetch(`https://aggregator.walrus-testnet.walrus.space/v1/${blobId}`);
const reportData = await content.json();

console.log('Report Content:', reportData);
```

---

## Testing Checklist

- [ ] Connect to Sui devnet
- [ ] Create a test bounty program
- [ ] Submit a test bug report
- [ ] Acknowledge report as project owner
- [ ] Accept report and set payout
- [ ] Execute payout
- [ ] Claim payout as researcher
- [ ] Create triage vote
- [ ] Cast votes
- [ ] Finalize vote
- [ ] Request early disclosure
- [ ] Approve early disclosure
- [ ] Publish public disclosure
- [ ] Subscribe to and verify events
- [ ] Query historical data

---

## Support & Resources

- **Package Explorer (Testnet):** https://testnet.suivision.xyz/package/0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802
- **SuiScan (Testnet):** https://suiscan.xyz/testnet/object/0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802
- **Sui TypeScript SDK:** https://sdk.mystenlabs.com/typescript
- **Walrus Documentation:** https://docs.walrus.site
- **Sui RPC Documentation:** https://docs.sui.io/references/sui-api
- **Testnet Faucet:** https://faucet.sui.io

---

## Changelog

**Version 1.0 - 2025-11-23 (Testnet)**
- Deployed to Sui Testnet (moved from Devnet)
- **Minimum bounty escrow reduced to 0.1 SUI** (from 10 SUI) for testnet ease of use
- 47 modules in main package
- 10 modules in communications package
- All core features operational
- All package and object IDs updated

**Version 1.0 - 2025-11-20 (Devnet)**
- Redeployed to devnet after network reset
- Previous deployment (deprecated - moved to testnet)

---

*Generated on 2025-11-23 for SuiGuard v1.0 Testnet*
