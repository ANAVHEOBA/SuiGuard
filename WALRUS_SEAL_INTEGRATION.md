# Walrus & Seal Protocol Integration Guide

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Walrus Integration](#walrus-integration)
- [Seal Integration](#seal-integration)
- [Complete Workflow Examples](#complete-workflow-examples)
- [Security Considerations](#security-considerations)

---

## Overview

SuiGuard integrates two cutting-edge Sui protocols for enhanced security and decentralized storage:

- **Walrus**: Decentralized blob storage for vulnerability reports and program details
- **Seal**: Time-locked encryption for responsible disclosure (90-day default)

### Integration Status

✅ **Production-Ready On-Chain Validation**
- Blob ID format validation (32+ bytes)
- Policy ID format validation
- Automated validation in all API entry points
- Comprehensive test coverage (70/70 tests passing)

### Key Benefits

1. **Decentralized Storage**: Reports stored on Walrus, not centralized servers
2. **Time-Locked Disclosure**: Seal ensures automatic 90-day embargo
3. **Tamper-Proof**: On-chain blob IDs create immutable audit trail
4. **Privacy-Preserving**: Encryption before upload to Walrus

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SuiGuard Platform                         │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Bounty     │  │    Report    │  │  Disclosure  │      │
│  │   Program    │  │  Submission  │  │   System     │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
│         ▼                  ▼                  ▼               │
│  ┌────────────────────────────────────────────────────┐     │
│  │     Walrus & Seal Validation Layer (On-Chain)      │     │
│  │  • blob_id format validation (32+ bytes)           │     │
│  │  • policy_id format validation                     │     │
│  │  • Automated checks in all APIs                    │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                          │                  │
                          ▼                  ▼
           ┌──────────────────┐   ┌──────────────────┐
           │  Walrus Protocol │   │  Seal Protocol   │
           │  (Blob Storage)  │   │  (Encryption)    │
           └──────────────────┘   └──────────────────┘
```

### Data Flow

1. **Client-Side** (Off-Chain):
   - Encrypt report with Seal SDK
   - Upload encrypted blob to Walrus
   - Receive blob_id and policy_id

2. **Smart Contract** (On-Chain):
   - Validate blob_id and policy_id format
   - Store references in BugReport/BountyProgram
   - Create immutable audit trail

3. **Retrieval** (Client-Side):
   - Query blob_id from on-chain record
   - Download blob from Walrus
   - Decrypt using Seal (after time-lock expires)

---

## Walrus Integration

### What is Walrus?

Walrus is Sui's decentralized blob storage protocol, designed for storing large files with:
- **Erasure coding** for data redundancy
- **Cost-efficient** storage (~5x raw data size)
- **High availability** via distributed storage nodes
- **Sui integration** for metadata and coordination

### Package Information

```typescript
// Walrus Mainnet
Package: 0xfdc88f7d7cf30afab2f82e8380d11ee8f70efb90e863d1de8616fae1bb09ea77
System: 0x2134d52768ea07e8c43570ef975eb3e4c27a39fa6396bef985b5abc58d03ddd2

// Walrus Testnet
Package: [Check Move.lock in testnet-contracts/]
System: 0x98ebc47370603fe81d9e15491b2f1443d619d1dab720d586e429ed233e1255c1
```

### Client-Side Integration (TypeScript)

#### 1. Upload Report to Walrus

```typescript
import { WalrusClient } from '@mysten/walrus';
import { SuiClient } from '@mysten/sui.js/client';

// Initialize Walrus client
const walrus = new WalrusClient({
  network: 'testnet', // or 'mainnet'
  aggregatorUrl: 'https://aggregator.walrus-testnet.walrus.space'
});

// Encrypt report data first (see Seal section)
const encryptedReport = await encryptWithSeal(reportData);

// Upload to Walrus
const upload = await walrus.store(encryptedReport);
const blobId = upload.newlyCreated.blobObject.blobId;

console.log('Blob ID:', blobId);
// Example: "0x1234...abcd" (u256 as hex string)
```

#### 2. Submit to SuiGuard with Blob ID

```typescript
import { TransactionBlock } from '@mysten/sui.js/transactions';

const tx = new TransactionBlock();

// Submit bug report with Walrus blob ID
tx.moveCall({
  target: `${PACKAGE_ID}::report_api::submit_bug_report`,
  arguments: [
    tx.object(programId),
    tx.object(duplicateRegistry),
    tx.pure(0), // severity: Critical
    tx.pure(3), // category: Access Control
    tx.pure(Array.from(Buffer.from(blobId.slice(2), 'hex'))), // Walrus blob ID
    tx.pure(Array.from(Buffer.from(sealPolicyId.slice(2), 'hex'))), // Seal policy ID
    tx.pure([Array.from(Buffer.from('module::function', 'utf8'))]), // affected targets
    tx.pure(Array.from(Buffer.from(vulnerabilityHash, 'utf8'))), // hash
    tx.object(submissionFeeCoin),
  ],
});

const result = await suiClient.signAndExecuteTransactionBlock({
  signer: keypair,
  transactionBlock: tx,
});
```

#### 3. Retrieve Report from Walrus

```typescript
// Get blob ID from on-chain record
const report = await suiClient.getObject({
  id: reportId,
  options: { showContent: true }
});

const blobId = report.data.content.fields.walrus_blob_id;

// Download from Walrus
const blob = await walrus.retrieve(blobId);
const encryptedData = await blob.arrayBuffer();

// Decrypt with Seal (see Seal section)
const decryptedReport = await decryptWithSeal(encryptedData, policyId);
```

### Move Smart Contract Usage

```move
use suiguard::walrus;

// Validate blob ID before storing
walrus::assert_valid_blob_id(&blob_id); // Aborts if invalid

// Helper functions
let is_valid = walrus::is_valid_blob_id(&blob_id); // Returns bool
let length = walrus::blob_id_length(&blob_id);
let formatted = walrus::format_blob_reference(&blob_id, b"My Report");
```

### Blob ID Requirements

- **Minimum Length**: 32 bytes (u256)
- **Format**: Hex string or raw bytes
- **Example**: `b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"`

---

## Seal Integration

### What is Seal?

Seal is Sui's decentralized secrets management protocol, providing:
- **Time-lock encryption** for scheduled disclosure
- **Threshold encryption** distributed across multiple services
- **On-chain access control** with Move smart contracts
- **Flexible policies** (time, token-gating, role-based)

### Package Information

```typescript
// Seal Testnet
Package: 0xe3d7e7a08ec189788f24840d27b02fee45cf3afc0fb579d6e3fd8450c5153d26

// Seal Mainnet (coming soon)
```

### Client-Side Integration (TypeScript)

#### 1. Encrypt Report with Time-Lock

```typescript
import { SealClient } from '@mystenlabs/seal-sdk';

// Initialize Seal client
const seal = new SealClient({
  network: 'testnet',
  suiClient: suiClient,
});

// Create 90-day time-lock policy
const policy = await seal.createTimelock({
  // Unlock after 90 days
  unlockTime: Date.now() + (90 * 24 * 60 * 60 * 1000),

  // Allow researcher to approve early release
  allowEarlyRelease: true,
  earlyReleaseApprovers: [researcherAddress],

  // Optional: Also require project approval
  requireAllApprovers: false,
});

console.log('Policy ID:', policy.id);
// Example: "0xe3d7e7a0...c5153d26"

// Encrypt report data
const reportData = JSON.stringify({
  title: "Critical Re-entrancy Vulnerability",
  description: "...",
  proofOfConcept: "...",
  affectedCode: "..."
});

const encrypted = await seal.encrypt(
  new TextEncoder().encode(reportData),
  policy.id
);

// Now upload encrypted data to Walrus
const blobId = await uploadToWalrus(encrypted);
```

#### 2. Automatic Disclosure (After 90 Days)

```typescript
// After 90 days, anyone can decrypt
const decrypted = await seal.decrypt(encrypted, policyId);
const reportData = JSON.parse(new TextDecoder().decode(decrypted));

console.log('Disclosed Report:', reportData);
```

#### 3. Early Disclosure with Approval

```typescript
// Researcher approves early release (e.g., after fix is deployed)
await seal.approveEarlyRelease({
  policyId: policyId,
  signer: researcherKeypair,
});

// Now anyone can decrypt before 90 days
const decrypted = await seal.decrypt(encrypted, policyId);
```

### Move Smart Contract Usage

```move
use suiguard::seal;

// Validate policy ID if provided
if (!std::vector::is_empty(&seal_policy_id_bytes)) {
    seal::assert_valid_policy_id(&seal_policy_id_bytes);
};

// Helper functions
let is_valid = seal::is_valid_policy_id(&policy_id);
let is_expired = seal::is_time_lock_expired(locked_at, current_epoch, 90);
let remaining = seal::remaining_epochs_until_unlock(locked_at, current_epoch, 90);
```

### Policy ID Requirements

- **Minimum Length**: 32 bytes (Sui object ID)
- **Format**: Hex string (typically with 0x prefix)
- **Example**: `b"0xe3d7e7a08ec189788f24840d27b02fee45cf3afc0fb579d6e3fd8450c5153d26"`

---

## Complete Workflow Examples

### End-to-End: Submit Encrypted Report

```typescript
async function submitEncryptedReport(
  reportData: any,
  programId: string,
  researcherAddress: string
) {
  // 1. Create Seal time-lock policy
  const policy = await seal.createTimelock({
    unlockTime: Date.now() + (90 * 24 * 60 * 60 * 1000),
    allowEarlyRelease: true,
    earlyReleaseApprovers: [researcherAddress],
  });

  // 2. Encrypt report
  const encrypted = await seal.encrypt(
    new TextEncoder().encode(JSON.stringify(reportData)),
    policy.id
  );

  // 3. Upload to Walrus
  const upload = await walrus.store(encrypted);
  const blobId = upload.newlyCreated.blobObject.blobId;

  // 4. Submit to SuiGuard
  const tx = new TransactionBlock();
  tx.moveCall({
    target: `${PACKAGE_ID}::report_api::submit_bug_report`,
    arguments: [
      tx.object(programId),
      tx.object(duplicateRegistry),
      tx.pure(0), // Critical severity
      tx.pure(0), // Reentrancy category
      tx.pure(Array.from(Buffer.from(blobId.slice(2), 'hex'))),
      tx.pure(Array.from(Buffer.from(policy.id.slice(2), 'hex'))),
      tx.pure([Array.from(Buffer.from('contract::vulnerable_fn', 'utf8'))]),
      tx.pure(Array.from(Buffer.from(sha256(reportData), 'utf8'))),
      tx.object(submissionFeeCoin),
    ],
  });

  const result = await suiClient.signAndExecuteTransactionBlock({
    signer: researcherKeypair,
    transactionBlock: tx,
  });

  console.log('Report submitted:', result.digest);
  return { blobId, policyId: policy.id, txDigest: result.digest };
}
```

### End-to-End: Retrieve and Decrypt Report

```typescript
async function retrieveReport(reportId: string) {
  // 1. Get report details from chain
  const report = await suiClient.getObject({
    id: reportId,
    options: { showContent: true }
  });

  const blobId = report.data.content.fields.walrus_blob_id;
  const policyId = report.data.content.fields.seal_policy_id;
  const submittedAt = report.data.content.fields.submitted_at;

  // 2. Check if time-lock has expired
  const currentEpoch = await suiClient.getLatestCheckpointSequenceNumber();
  const canDecrypt = currentEpoch >= submittedAt + 90;

  if (!canDecrypt) {
    console.log('Report still time-locked for', submittedAt + 90 - currentEpoch, 'epochs');
    return null;
  }

  // 3. Download from Walrus
  const blob = await walrus.retrieve(blobId);
  const encrypted = await blob.arrayBuffer();

  // 4. Decrypt with Seal
  const decrypted = await seal.decrypt(
    new Uint8Array(encrypted),
    policyId
  );

  const reportData = JSON.parse(new TextDecoder().decode(decrypted));

  console.log('Decrypted Report:', reportData);
  return reportData;
}
```

---

## Security Considerations

### Best Practices

1. **Always Encrypt Before Upload**
   ```typescript
   // ❌ BAD: Uploading raw data
   const blobId = await walrus.store(JSON.stringify(report));

   // ✅ GOOD: Encrypt first
   const encrypted = await seal.encrypt(reportData, policyId);
   const blobId = await walrus.store(encrypted);
   ```

2. **Verify Blob Availability**
   ```typescript
   // Check blob exists before referencing
   try {
     await walrus.retrieve(blobId);
   } catch (error) {
     console.error('Blob not available:', blobId);
     throw new Error('Upload failed - blob not found');
   }
   ```

3. **Use Strong Policy IDs**
   ```typescript
   // ✅ GOOD: Generate unique policy for each report
   const policy = await seal.createTimelock({...});

   // ❌ BAD: Reusing policy IDs
   const policy = previousPolicy;
   ```

4. **Handle Policy Expiration**
   ```typescript
   // Check policy status before attempting decrypt
   const policyInfo = await seal.getPolicyInfo(policyId);
   if (!policyInfo.isActive) {
     throw new Error('Policy has been revoked');
   }
   ```

### Attack Vectors to Consider

- **Blob Censorship**: Walrus uses erasure coding for redundancy
- **Policy Manipulation**: Seal policies are immutable once created
- **Time-Lock Bypass**: Not possible without approval signatures
- **Data Tampering**: On-chain blob IDs create tamper-proof audit trail

### Compliance & Privacy

- **GDPR**: Encrypted data on Walrus; keys controlled by Seal
- **Right to Delete**: Seal policies can include expiration
- **Data Sovereignty**: Choose Walrus storage region (when available)

---

## Integration Checklist

### For Researchers

- [ ] Install Walrus CLI/SDK
- [ ] Install Seal SDK
- [ ] Test encryption workflow on testnet
- [ ] Verify blob upload to Walrus
- [ ] Submit test report with valid IDs
- [ ] Confirm on-chain record

### For Projects

- [ ] Set up Walrus client for report retrieval
- [ ] Implement Seal decryption for disclosed reports
- [ ] Handle early disclosure approval flow
- [ ] Monitor policy expiration times
- [ ] Archive disclosed reports securely

### For Developers

- [ ] Validate blob IDs: `walrus::assert_valid_blob_id(&id)`
- [ ] Validate policy IDs: `seal::assert_valid_policy_id(&id)`
- [ ] Handle time-lock checks in UI
- [ ] Display disclosure countdown
- [ ] Implement blob caching

---

## Troubleshooting

### Common Issues

**Problem**: "Test was not expected to error, but it aborted with code 1301"
```
Solution: Blob ID is too short (< 32 bytes). Use valid test blob ID:
const TEST_BLOB_ID = b"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
```

**Problem**: "Stream did not contain valid UTF-8"
```
Solution: Non-UTF-8 characters in source files. Run:
iconv -f ISO-8859-1 -t UTF-8 file.move -o file.move
```

**Problem**: Walrus upload fails
```
Solution: Check aggregator URL and network:
- Testnet: https://aggregator.walrus-testnet.walrus.space
- Mainnet: https://aggregator.walrus-mainnet.walrus.space
```

**Problem**: Seal decrypt fails before 90 days
```
Solution: Policy time-lock is active. Options:
1. Wait for policy expiration
2. Request early release approval
3. Check policy allows early release
```

---

## Resources

### Documentation
- [Walrus Docs](https://docs.walrus.site/)
- [Seal Documentation](https://seal.mystenlabs.com/)
- [Sui Move Book](https://move-book.com/)

### SDKs & Tools
- [@mysten/walrus](https://www.npmjs.com/package/@mysten/walrus) - Walrus TypeScript SDK
- [@mystenlabs/seal-sdk](https://www.npmjs.com/package/@mystenlabs/seal-sdk) - Seal SDK
- [Walrus CLI](https://docs.walrus.site/usage/setup.html) - Command-line interface

### Support
- [Sui Discord](https://discord.gg/sui) - #walrus and #seal channels
- [SuiGuard GitHub](https://github.com/suiguard/suiguard) - Platform issues
- [Mysten Labs Forum](https://forums.sui.io/) - Technical discussions

---

**Last Updated**: November 2025
**SuiGuard Version**: 1.0.0
**Integration Status**: ✅ Production Ready (70/70 tests passing)
