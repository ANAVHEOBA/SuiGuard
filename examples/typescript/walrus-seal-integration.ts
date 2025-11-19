/**
 * SuiGuard - Walrus & Seal Integration Example
 *
 * This example demonstrates how to integrate Walrus decentralized storage
 * and Seal time-locked encryption for secure vulnerability reporting.
 *
 * Prerequisites:
 * - npm install @mysten/sui.js @mysten/walrus @mystenlabs/seal-sdk
 * - Set up Sui wallet with testnet SUI
 */

import { SuiClient, getFullnodeUrl } from '@mysten/sui.js/client';
import { TransactionBlock } from '@mysten/sui.js/transactions';
import { Ed25519Keypair } from '@mysten/sui.js/keypairs/ed25519';
import { WalrusClient } from '@mysten/walrus';
import { SealClient } from '@mystenlabs/seal-sdk';

// Configuration
const NETWORK = 'testnet';
const SUIGUARD_PACKAGE_ID = 'YOUR_PACKAGE_ID_HERE';
const WALRUS_AGGREGATOR = 'https://aggregator.walrus-testnet.walrus.space';

// Initialize clients
const suiClient = new SuiClient({ url: getFullnodeUrl(NETWORK) });
const walrus = new WalrusClient({
  network: NETWORK,
  aggregatorUrl: WALRUS_AGGREGATOR,
});
const seal = new SealClient({
  network: NETWORK,
  suiClient: suiClient,
});

/**
 * Example 1: Submit an Encrypted Vulnerability Report
 */
export async function submitEncryptedReport(
  researcherKeypair: Ed25519Keypair,
  programId: string,
  reportData: any
) {
  const researcherAddress = researcherKeypair.getPublicKey().toSuiAddress();

  console.log('Step 1: Creating Seal time-lock policy...');
  // Create 90-day time-lock policy
  const policy = await seal.createTimelock({
    unlockTime: Date.now() + (90 * 24 * 60 * 60 * 1000), // 90 days
    allowEarlyRelease: true,
    earlyReleaseApprovers: [researcherAddress],
    requireAllApprovers: false,
  });

  console.log('Policy ID:', policy.id);

  console.log('Step 2: Encrypting report data...');
  // Encrypt the report
  const reportString = JSON.stringify(reportData);
  const encrypted = await seal.encrypt(
    new TextEncoder().encode(reportString),
    policy.id
  );

  console.log('Step 3: Uploading encrypted blob to Walrus...');
  // Upload to Walrus
  const upload = await walrus.store(encrypted);
  const blobId = upload.newlyCreated.blobObject.blobId;

  console.log('Blob ID:', blobId);

  console.log('Step 4: Submitting to SuiGuard smart contract...');
  // Submit to SuiGuard
  const tx = new TransactionBlock();

  // Get registry objects
  const duplicateRegistry = await getDuplicateRegistry(suiClient);

  // Create submission fee coin (10 SUI)
  const [submissionFeeCoin] = tx.splitCoins(tx.gas, [
    tx.pure(10_000_000_000),
  ]);

  // Call submit_bug_report
  tx.moveCall({
    target: `${SUIGUARD_PACKAGE_ID}::report_api::submit_bug_report`,
    arguments: [
      tx.object(programId),
      tx.object(duplicateRegistry),
      tx.pure(0), // severity: Critical
      tx.pure(0), // category: Reentrancy
      tx.pure(Array.from(Buffer.from(blobId.slice(2), 'hex'))), // Walrus blob ID
      tx.pure(Array.from(Buffer.from(policy.id.slice(2), 'hex'))), // Seal policy ID
      tx.pure([Array.from(Buffer.from('contract::vulnerable_function', 'utf8'))]), // affected targets
      tx.pure(Array.from(Buffer.from(hashReport(reportData), 'utf8'))), // vulnerability hash
      submissionFeeCoin,
    ],
  });

  const result = await suiClient.signAndExecuteTransactionBlock({
    signer: researcherKeypair,
    transactionBlock: tx,
    options: {
      showEffects: true,
      showEvents: true,
    },
  });

  console.log('✅ Report submitted successfully!');
  console.log('Transaction:', result.digest);

  return {
    blobId,
    policyId: policy.id,
    txDigest: result.digest,
  };
}

/**
 * Example 2: Retrieve and Decrypt a Disclosed Report
 */
export async function retrieveDisclosedReport(reportId: string) {
  console.log('Step 1: Fetching report from blockchain...');

  // Get report object
  const report = await suiClient.getObject({
    id: reportId,
    options: { showContent: true },
  });

  if (!report.data?.content || report.data.content.dataType !== 'moveObject') {
    throw new Error('Report not found or invalid');
  }

  const fields = report.data.content.fields as any;
  const blobId = bytesToHex(fields.walrus_blob_id);
  const policyId = fields.seal_policy_id
    ? bytesToHex(fields.seal_policy_id)
    : null;
  const submittedAt = parseInt(fields.submitted_at);

  console.log('Report Details:');
  console.log('- Blob ID:', blobId);
  console.log('- Policy ID:', policyId);
  console.log('- Submitted At:', submittedAt);

  console.log('\nStep 2: Checking time-lock status...');

  // Check if can decrypt (90 epochs passed)
  const currentEpoch = await suiClient.getLatestCheckpointSequenceNumber();
  const canDecrypt = currentEpoch >= submittedAt + 90;

  if (!canDecrypt) {
    const remaining = submittedAt + 90 - currentEpoch;
    console.log(`⏱️  Report still time-locked for ${remaining} epochs`);
    return null;
  }

  console.log('✅ Time-lock expired, can decrypt');

  console.log('\nStep 3: Downloading blob from Walrus...');

  // Download from Walrus
  const blob = await walrus.retrieve(blobId);
  const encrypted = await blob.arrayBuffer();

  console.log(`Downloaded ${encrypted.byteLength} bytes`);

  if (!policyId) {
    // No Seal encryption, just return raw data
    return JSON.parse(new TextDecoder().decode(encrypted));
  }

  console.log('\nStep 4: Decrypting with Seal...');

  // Decrypt with Seal
  const decrypted = await seal.decrypt(new Uint8Array(encrypted), policyId);

  const reportData = JSON.parse(new TextDecoder().decode(decrypted));

  console.log('✅ Successfully decrypted report');

  return reportData;
}

/**
 * Example 3: Request Early Disclosure (with researcher approval)
 */
export async function requestEarlyDisclosure(
  researcherKeypair: Ed25519Keypair,
  reportId: string
) {
  console.log('Step 1: Fetching report details...');

  const report = await suiClient.getObject({
    id: reportId,
    options: { showContent: true },
  });

  const fields = (report.data?.content as any)?.fields;
  const policyId = fields.seal_policy_id
    ? bytesToHex(fields.seal_policy_id)
    : null;

  if (!policyId) {
    throw new Error('Report has no Seal policy');
  }

  console.log('Policy ID:', policyId);

  console.log('\nStep 2: Approving early release...');

  // Researcher approves early release
  await seal.approveEarlyRelease({
    policyId: policyId,
    signer: researcherKeypair,
  });

  console.log('✅ Early release approved');
  console.log('Report can now be decrypted before 90 days');

  // Now anyone can decrypt
  return await retrieveDisclosedReport(reportId);
}

/**
 * Example 4: Create a Bounty Program with Walrus Details
 */
export async function createBountyProgram(
  ownerKeypair: Ed25519Keypair,
  programDetails: any
) {
  console.log('Step 1: Uploading program details to Walrus...');

  // Upload program details (public, no encryption needed)
  const detailsBlob = new TextEncoder().encode(JSON.stringify(programDetails));
  const upload = await walrus.store(detailsBlob);
  const blobId = upload.newlyCreated.blobObject.blobId;

  console.log('Blob ID:', blobId);

  console.log('\nStep 2: Creating bounty program on-chain...');

  const tx = new TransactionBlock();

  // Get registry
  const registry = await getBountyProgramRegistry(suiClient);

  // Create escrow coin (100,000 SUI)
  const [escrowCoin] = tx.splitCoins(tx.gas, [tx.pure(100_000_000_000_000)]);

  // Call create_bounty_program
  tx.moveCall({
    target: `${SUIGUARD_PACKAGE_ID}::bounty_api::create_bounty_program`,
    arguments: [
      tx.object(registry),
      tx.pure(Array.from(Buffer.from(programDetails.name, 'utf8'))),
      tx.pure(Array.from(Buffer.from(programDetails.description, 'utf8'))),
      escrowCoin,
      tx.pure(50_000_000_000_000), // Critical: 50k SUI
      tx.pure(20_000_000_000_000), // High: 20k SUI
      tx.pure(5_000_000_000_000), // Medium: 5k SUI
      tx.pure(1_000_000_000_000), // Low: 1k SUI
      tx.pure(100_000_000_000), // Informational: 100 SUI
      tx.pure(Array.from(Buffer.from(blobId.slice(2), 'hex'))), // Walrus blob ID
      tx.pure(90), // duration: 90 days
    ],
  });

  const result = await suiClient.signAndExecuteTransactionBlock({
    signer: ownerKeypair,
    transactionBlock: tx,
    options: {
      showEffects: true,
    },
  });

  console.log('✅ Bounty program created!');
  console.log('Transaction:', result.digest);

  return result;
}

// ==================== Helper Functions ====================

function bytesToHex(bytes: number[]): string {
  return (
    '0x' +
    bytes
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('')
  );
}

function hashReport(reportData: any): string {
  // In production, use proper cryptographic hash
  return JSON.stringify(reportData);
}

async function getDuplicateRegistry(client: SuiClient): Promise<string> {
  // Implement logic to find DuplicateRegistry object
  return 'YOUR_DUPLICATE_REGISTRY_ID';
}

async function getBountyProgramRegistry(client: SuiClient): Promise<string> {
  // Implement logic to find ProgramRegistry object
  return 'YOUR_PROGRAM_REGISTRY_ID';
}

// ==================== Usage Examples ====================

async function main() {
  // Load researcher keypair
  const researcherKeypair = Ed25519Keypair.fromSecretKey(
    Buffer.from('YOUR_SECRET_KEY_HERE', 'hex')
  );

  // Example 1: Submit encrypted report
  const reportData = {
    title: 'Critical Reentrancy Vulnerability',
    description: 'The contract allows reentrancy attacks...',
    severity: 'Critical',
    affectedFunctions: ['withdraw', 'transfer'],
    proofOfConcept: `
      contract Exploit {
        function attack() external {
          // Attack code here
        }
      }
    `,
    remediation: 'Add reentrancy guard',
  };

  const submission = await submitEncryptedReport(
    researcherKeypair,
    'YOUR_PROGRAM_ID',
    reportData
  );

  console.log('\n📝 Report Submitted:');
  console.log(JSON.stringify(submission, null, 2));

  // Example 2: After 90 days, retrieve report
  // const disclosed = await retrieveDisclosedReport(submission.txDigest);
  // console.log('\n🔓 Disclosed Report:', disclosed);

  // Example 3: Request early disclosure
  // const earlyDisclosed = await requestEarlyDisclosure(
  //   researcherKeypair,
  //   submission.txDigest
  // );
}

// Uncomment to run
// main().catch(console.error);

export { suiClient, walrus, seal };
