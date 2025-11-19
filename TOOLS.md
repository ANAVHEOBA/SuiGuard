# SuiGuard Technology Stack

## Overview of Tools & Infrastructure

---

## Core Technologies

### 1. Sui Blockchain
**What:** Layer-1 blockchain optimized for horizontal scaling and low latency

**Why We're Using It:**
- **Object-Centric Model:** Perfect for representing bounty programs, bug reports, and reputation as distinct objects
- **Move Language:** Formal verification capabilities help us build secure smart contracts
- **Parallel Execution:** Fast transaction finality for instant payouts
- **Native Sponsored Transactions:** Projects can pay gas fees for researchers

**How We Use It:**
- Smart contracts for all core logic (escrow, voting, payouts)
- On-chain reputation system
- Event emission for indexing
- Native SUI/USDC for bounty payments

**Documentation:**
- https://docs.sui.io/
- https://github.com/MystenLabs/sui

---

### 2. Walrus - Decentralized Storage
**What:** Decentralized blob storage network built for the Sui ecosystem

**Why We're Using It:**
- **Permanent Storage:** Bug reports and audit archives never disappear
- **Cost-Effective:** Cheaper than storing large data on-chain
- **Censorship-Resistant:** No single entity can delete vulnerability disclosures
- **High Availability:** Redundant storage across multiple nodes
- **Native Sui Integration:** Store blob IDs on-chain, retrieve via Walrus API

**How We Use It:**

#### Use Case 1: Bug Report Storage
```javascript
// Researcher uploads encrypted bug report
const bugReport = {
  title: "Reentrancy vulnerability in withdraw function",
  description: "Detailed exploit explanation...",
  proofOfConcept: "// Exploit code here",
  affectedCode: "contract address + function signature",
  severity: "Critical",
  attachments: ["screenshot1.png", "test_output.txt"]
};

// Encrypt before upload
const encryptedReport = await encryptWithSeal(bugReport, sealPolicy);

// Upload to Walrus
const walrusBlobId = await walrusClient.upload(encryptedReport);

// Store blob ID on-chain
await suiContract.submitBugReport({
  walrusBlobId: walrusBlobId,
  sealPolicyId: sealPolicy.id
});
```

#### Use Case 2: Bounty Program Details
```javascript
// Project uploads program scope and rules
const programDetails = {
  projectName: "Cetus Protocol",
  scope: {
    inScope: ["contracts/pool.move", "contracts/swap.move"],
    outOfScope: ["frontend/*", "docs/*"]
  },
  rules: "No DDoS, no social engineering...",
  contactEmail: "security@cetus.zone"
};

const blobId = await walrusClient.upload(programDetails);

// Reference in smart contract
await suiContract.createBountyProgram({
  detailsBlobId: blobId,
  escrowAmount: "100000 SUI"
});
```

#### Use Case 3: Audit Report Archive
```javascript
// Permanently archive all historical reports
const archivedReport = {
  bugReportId: "0x123abc...",
  finalSeverity: "Critical",
  payoutAmount: "50000 SUI",
  fixCommitHash: "a7f3d9e...",
  disclosureDate: "2025-03-15",
  fullReport: decryptedBugDetails
};

const archiveBlobId = await walrusClient.upload(archivedReport);

// Searchable index stored on-chain
await suiContract.archiveReport(bugReportId, archiveBlobId);
```

**Walrus Architecture:**
- **Blob Storage:** Files split into chunks and distributed
- **Erasure Coding:** Redundancy without full replication
- **Content Addressing:** Retrieve by blob ID
- **Expiry Management:** Can set storage duration or permanent storage

**Documentation:**
- https://docs.walrus.site/
- https://github.com/MystenLabs/walrus-docs

---

### 3. Seal - Policy-Based Access Control
**What:** Decentralized encryption and access control system for Walrus

**Why We're Using It:**
- **Time-Locked Disclosure:** Automatically make reports public after 90 days
- **Multi-Party Decryption:** Researcher + Project both have access
- **Policy Enforcement:** Access rules enforced cryptographically, not by centralized server
- **Conditional Access:** Can set complex rules (e.g., "only after DAO vote" or "only if fix deployed")

**How We Use It:**

#### Use Case 1: Time-Locked Disclosure Policy
```javascript
// Create Seal policy for bug report
const sealPolicy = await sealClient.createPolicy({
  name: "90-Day Responsible Disclosure",
  accessRules: [
    {
      // Researcher always has access
      principal: researcherAddress,
      permission: "decrypt",
      condition: "always"
    },
    {
      // Project always has access (until fix deployed)
      principal: projectAddress,
      permission: "decrypt",
      condition: "always"
    },
    {
      // Public access after 90 days
      principal: "*", // Anyone
      permission: "decrypt",
      condition: {
        type: "time_lock",
        unlock_time: currentTime + 90 * 24 * 60 * 60 * 1000
      }
    }
  ],
  encryptionKey: generatedKey
});

// Encrypt bug report with this policy
const encrypted = await sealPolicy.encrypt(bugReportData);
```

#### Use Case 2: Conditional Early Disclosure
```javascript
// Update policy when fix is deployed
await sealPolicy.addRule({
  principal: "*",
  permission: "decrypt",
  condition: {
    type: "smart_contract_state",
    contract: bountyProgramAddress,
    check: "fix_deployed == true"
  }
});

// Now anyone can decrypt IF fix is deployed OR 90 days passed
```

#### Use Case 3: Multi-Sig Access
```javascript
// Require 2-of-3 signatures to decrypt sensitive reports
const multiSigPolicy = await sealClient.createPolicy({
  accessRules: [{
    principals: [auditor1, auditor2, auditor3],
    permission: "decrypt",
    threshold: 2, // Require 2 of 3 signatures
    condition: "dispute_filed == true"
  }]
});
```

**Seal Features:**
- **Threshold Encryption:** M-of-N access control
- **Policy Composition:** Combine multiple conditions (AND/OR logic)
- **Revocation:** Can revoke access even after encryption
- **Audit Trail:** Track who decrypted what and when

**Documentation:**
- https://github.com/MystenLabs/seal (hypothetical - adjust to actual docs)

---

### 4. Nautilus - Trusted Execution Environment (TEE)
**What:** Confidential computing platform using Intel SGX/TDX for isolated code execution

**Why We're Using It:**
- **Verifiable PoC Execution:** Run exploit code in isolation to prove it works
- **Cryptographic Attestation:** Generate unforgeable proof that exploit succeeded
- **No Mainnet Risk:** Test exploits without touching live contracts
- **Privacy:** Exploit code never exposed publicly
- **Trust Minimization:** Projects can verify bugs are real without trusting researcher

**How We Use It:**

#### Use Case 1: Exploit Proof-of-Concept Verification
```javascript
// Researcher submits PoC to Nautilus
const pocCode = `
  // Exploit code that drains contract
  public entry fun exploit(pool: &mut Pool) {
    // Reentrancy attack
    while (pool.balance > 0) {
      pool.withdraw(pool.balance);
    }
  }
`;

// Nautilus executes in isolated enclave
const result = await nautilusClient.executePoC({
  code: pocCode,
  targetContract: "0xCETUS_POOL",
  simulationFork: "mainnet_block_12345678" // Fork of real state
});

// Nautilus returns attestation
const attestation = {
  exploitConfirmed: true,
  fundsExtracted: "1000000 USDC",
  enclaveMeasurement: "0xABCDEF...", // SGX measurement
  signature: "0x123456...", // Signed by TEE private key
  timestamp: 1678901234
};

// Submit attestation to smart contract
await suiContract.verifyAttestation(bugReportId, attestation);
```

#### Use Case 2: Fix Verification
```javascript
// After project deploys fix, re-run exploit to confirm it's patched
const fixVerification = await nautilusClient.executePoC({
  code: originalPoCCode,
  targetContract: "0xCETUS_POOL_V2", // Updated contract
  simulationFork: "mainnet_latest"
});

// Result should show exploit failed
assert(fixVerification.exploitConfirmed === false);
assert(fixVerification.error === "WithdrawLimitExceeded");

// Confirm fix on-chain
await suiContract.confirmFixDeployed(bugReportId, fixVerification);
```

#### Use Case 3: On-Chain Attestation Verification
```move
// Smart contract verifies Nautilus attestation
public fun verify_nautilus_attestation(
    attestation_data: vector<u8>,
    signature: vector<u8>
): bool {
    // 1. Verify signature using Nautilus public key
    let nautilus_pubkey = @0xNAUTILUS_ATTESTATION_KEY;
    assert!(
        verify_signature(attestation_data, signature, nautilus_pubkey),
        E_INVALID_SIGNATURE
    );

    // 2. Verify enclave measurement is trusted
    let measurement = extract_measurement(&attestation_data);
    assert!(
        is_trusted_enclave(measurement),
        E_UNTRUSTED_ENCLAVE
    );

    // 3. Check timestamp freshness (< 24 hours old)
    let timestamp = extract_timestamp(&attestation_data);
    assert!(
        tx_context::epoch() - timestamp < 86400,
        E_STALE_ATTESTATION
    );

    true
}
```

**Nautilus Architecture:**
- **Intel SGX Enclaves:** Hardware-isolated execution
- **Remote Attestation:** Cryptographic proof of code + environment
- **Encrypted Memory:** PoC code never exposed to host OS
- **State Simulation:** Fork Sui blockchain state for safe testing

**Documentation:**
- https://docs.sui.io/guides/developer/cryptography/nautilus (hypothetical)

---

## Supporting Technologies

### 5. Sui Move Language
**What:** Smart contract programming language with focus on safety and formal verification

**Key Features for SuiGuard:**
- **Object Model:** Bounty programs, reports, reputation as owned objects
- **Capability-Based Security:** Access control via object ownership
- **No Reentrancy:** Move's design prevents classic reentrancy attacks
- **Integer Overflow Protection:** Built-in safe math

**Example Contract Structure:**
```move
module suiguard::bounty_program {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;

    struct BountyProgram has key, store {
        id: UID,
        project_owner: address,
        escrow: Balance<SUI>,
        severity_tiers: VecMap<u8, u64>,
        active: bool
    }

    public fun create_program(
        escrow: Coin<SUI>,
        ctx: &mut TxContext
    ): BountyProgram {
        BountyProgram {
            id: object::new(ctx),
            project_owner: tx_context::sender(ctx),
            escrow: coin::into_balance(escrow),
            severity_tiers: vec_map::empty(),
            active: true
        }
    }
}
```

---

### 6. Sui TypeScript SDK
**What:** Official SDK for interacting with Sui from JavaScript/TypeScript

**How We Use It:**
- Frontend interaction with smart contracts
- Transaction building and signing
- Event listening for real-time updates
- Wallet integration

```typescript
import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';

const client = new SuiClient({ url: getFullnodeUrl('mainnet') });

// Submit bug report transaction
const tx = new TransactionBlock();
tx.moveCall({
  target: `${PACKAGE_ID}::bug_report::submit`,
  arguments: [
    tx.object(BOUNTY_PROGRAM_ID),
    tx.pure(walrusBlobId),
    tx.pure(sealPolicyId)
  ]
});

const result = await client.signAndExecuteTransactionBlock({
  transactionBlock: tx,
  signer: keypair
});
```

---

### 7. GraphQL Indexer (Sui RPC)
**What:** Query historical blockchain data efficiently

**How We Use It:**
- Fetch all bug reports for a program
- Query researcher reputation history
- Build leaderboards and statistics
- Filter events by type

```graphql
query GetBugReports($programId: String!) {
  events(
    filter: {
      eventType: "BugReportSubmitted"
      sender: $programId
    }
  ) {
    nodes {
      timestamp
      txDigest
      parsedJson
    }
  }
}
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                     Frontend (React)                    │
│  - Submit bugs  - Create bounties  - Vote on severity   │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                 Sui TypeScript SDK                      │
└─────────────────────┬───────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┬──────────────┐
        │             │             │              │
        ▼             ▼             ▼              ▼
┌──────────┐  ┌──────────────┐  ┌──────┐  ┌──────────────┐
│   Sui    │  │   Walrus     │  │ Seal │  │  Nautilus    │
│Blockchain│  │   Storage    │  │Access│  │     TEE      │
│          │  │              │  │Control│  │              │
│ ┌──────┐ │  │ ┌──────────┐ │  │┌────┐│  │ ┌──────────┐ │
│ │Smart │ │  │ │Bug Report│ │  ││Time││  │ │PoC Exec  │ │
│ │Contracts│ │ │  Blobs   │ │  ││Lock││  │ │+ Attest  │ │
│ └──────┘ │  │ └──────────┘ │  │└────┘│  │ └──────────┘ │
│          │  │              │  │      │  │              │
│ - Escrow │  │ - Encrypted  │  │- 90d │  │ - SGX Enclave│
│ - Voting │  │ - Permanent  │  │- Multi│ │ - Crypto     │
│ - Payout │  │ - Redundant  │  │ Party│  │   Proof      │
└──────────┘  └──────────────┘  └──────┘  └──────────────┘
```

---

## Integration Flow

### Complete Bug Submission Flow:

```
1. Researcher discovers vulnerability
   ↓
2. Write PoC exploit code
   ↓
3. Submit to Nautilus TEE
   - Code runs in isolated environment
   - TEE generates attestation
   ↓
4. Encrypt bug report
   - Create Seal policy (time-lock + multi-party)
   - Encrypt report data
   ↓
5. Upload to Walrus
   - Store encrypted blob
   - Get blob ID
   ↓
6. Submit to Sui smart contract
   - Store: blob ID, Seal policy ID, attestation
   - Lock in submission fee
   ↓
7. DAO votes on severity
   - Community stakes SUI to vote
   - 48-hour voting period
   ↓
8. Smart contract executes payout
   - Release escrow to researcher
   - Update reputation
   ↓
9. Time-locked disclosure
   - Project has 90 days to fix
   - Seal automatically allows public access after deadline
   ↓
10. Archive to Walrus
    - Permanent record of vulnerability
    - Searchable database
```

---

## Development Tools

### Testing
- **Sui Move Analyzer:** Static analysis for smart contracts
- **Sui Move Prover:** Formal verification
- **Local Sui Network:** Development blockchain
- **Walrus Devnet:** Test storage network

### Deployment
- **Sui CLI:** Contract deployment and interaction
- **Walrus CLI:** Blob upload/download
- **GitHub Actions:** CI/CD pipeline

### Monitoring
- **Sui Explorer:** Transaction and object inspection
- **Custom Indexer:** Event processing and database
- **Grafana Dashboards:** Platform metrics

---

## Why This Stack Wins

### Technical Advantages:
✅ **Nautilus:** No other bug bounty platform has verifiable PoC execution
✅ **Seal:** Time-locked disclosure is cryptographically enforced, not trust-based
✅ **Walrus:** Censorship-resistant audit archives that can't be deleted
✅ **Sui:** Fast finality for instant payouts, object model for clean architecture

### Competitive Moat:
- **Immunefi/HackenProof:** Centralized, slow payouts, no PoC verification
- **Code4rena:** Competition-based, not continuous monitoring
- **Traditional Audits:** One-time, expensive, auditors miss bugs (see Cetus)

### Hackathon Fit:
- Uses **all three** required technologies (Walrus, Seal, Nautilus)
- Solves **real problem** ($260M Cetus hack)
- **Novel use case** for TEE (verifiable exploit execution)
- **Perfect timing** (Sui Foundation committed $10M to bug bounties)

---

## Next Steps

### 1. Set Up Development Environment
```bash
# Install Sui CLI
curl https://sui.io/install.sh | sh

# Install Walrus CLI
npm install -g @mysten/walrus-cli

# Clone starter template
git clone https://github.com/MystenLabs/sui-move-template
```

### 2. Build Smart Contracts
- Start with `bounty_program.move`
- Add `bug_report.move`
- Implement `reputation.move`

### 3. Integrate Walrus
- Set up blob storage client
- Test encryption/upload
- Implement retrieval

### 4. Add Seal Policies
- Create time-lock policy templates
- Test multi-party decryption
- Implement policy updates

### 5. Connect Nautilus
- Set up TEE client
- Build PoC execution sandbox
- Implement attestation verification

### 6. Frontend
- React + Sui dApp Kit
- Wallet connection
- Bug submission form
- Voting interface

Ready to start building? 🚀
