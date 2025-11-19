# SuiGuard Reward Mechanism Design

## Code Submission Process

### How Projects Submit Their Code

#### **Option 1: GitHub Integration (Recommended)**
```javascript
// Project connects GitHub repo
const submission = {
  repoUrl: "https://github.com/cetus-protocol/cetus-core",
  branch: "main",
  commitHash: "a7f3d9e...", // Specific commit for audit
  scope: {
    inScope: [
      "contracts/pool.move",
      "contracts/swap.move",
      "contracts/router.move"
    ],
    outOfScope: [
      "tests/*",
      "scripts/*",
      "frontend/*"
    ]
  }
};

// System automatically:
// 1. Clones repo at specific commit
// 2. Uploads to Walrus for permanent storage
// 3. Generates merkle root of all files (tamper-proof)
// 4. Stores Walrus blob ID on-chain
```

#### **Option 2: Direct Upload**
```javascript
// For private/unreleased code
// Project uploads zip file directly
const privateSubmission = {
  codeArchive: "encrypted_code.zip",
  encryptionKey: "shared only with verified researchers",
  walrusBlobId: "0xABC123..." // Encrypted upload to Walrus
};
```

#### **Option 3: Deployed Contract Analysis**
```javascript
// For already-deployed contracts
const deployedSubmission = {
  packageId: "0x1234...",
  modules: ["pool", "swap", "vault"],
  deploymentTx: "0xABCD...",
  sourceCodeProof: walrusBlobId // Source must match deployed bytecode
};
```

### Code Verification on Walrus
```
Project uploads code → Walrus stores permanently → Returns blob ID
                                                          ↓
                        Smart contract stores blob ID + merkle root
                                                          ↓
                        Researchers download via blob ID
                                                          ↓
                        System verifies merkle root matches
                                                          ↓
                        If tampered → Report invalid
```

---

## Reward Calculation Models

### **Model A: Fixed Tier (Like Immunefi) - RECOMMENDED FOR MVP**

#### How It Works:
- Project sets fixed USD amounts per severity level
- Clear, predictable payouts
- No competition, no splitting

#### Example Configuration:
```javascript
const bountyProgram = {
  projectName: "Cetus Protocol",
  rewardTiers: {
    CRITICAL: {
      amount: 50000, // USD
      currency: "SUI", // Paid in SUI equivalent
      conditions: "Direct loss of funds or total protocol halt"
    },
    HIGH: {
      amount: 20000,
      conditions: "Theft under specific conditions or temporary freeze"
    },
    MEDIUM: {
      amount: 5000,
      conditions: "Griefing attacks or denial of service"
    },
    LOW: {
      amount: 1000,
      conditions: "Best practice violations"
    },
    INFORMATIONAL: {
      amount: 0, // No reward but builds reputation
      conditions: "Code quality suggestions"
    }
  },
  totalEscrow: 200000, // Must cover multiple bugs
  payoutCurrency: "SUI" // Or USDC
};
```

#### Payout Calculation:
```javascript
// Simple: Bug severity → Fixed amount
function calculatePayout(severity, program) {
  const baseAmount = program.rewardTiers[severity].amount;

  // Optional: Reputation bonus
  const researcherRep = getReputation(researcher);
  const bonus = researcherRep > 1000 ? 1.1 : 1.0; // 10% bonus for top researchers

  return baseAmount * bonus;
}

// Example:
// Critical bug by top researcher: $50,000 * 1.1 = $55,000
```

**Pros:**
- ✅ Simple and clear
- ✅ Predictable for projects
- ✅ Fair for researchers (no competition)
- ✅ Industry standard

**Cons:**
- ❌ Can be expensive if many bugs found
- ❌ No incentive for speed (first vs last reporter)

---

### **Model B: Prize Pool Split (Like Sherlock/Cantina)**

#### How It Works:
- Project sets total prize pool ($100k)
- All bugs found during period split the pool
- Distribution based on severity + uniqueness

#### Example Configuration:
```javascript
const competitionProgram = {
  projectName: "Cetus Protocol",
  totalPrizePool: 100000, // Fixed total amount
  duration: 14, // Days
  severityWeights: {
    CRITICAL: 10, // 10x weight
    HIGH: 5,
    MEDIUM: 2,
    LOW: 1
  }
};
```

#### Payout Calculation:
```javascript
function calculateCompetitivePayout(allBugs, researcher) {
  // Step 1: Calculate total weight
  const totalWeight = allBugs.reduce((sum, bug) => {
    return sum + competitionProgram.severityWeights[bug.severity];
  }, 0);

  // Step 2: Calculate researcher's share
  const researcherBugs = allBugs.filter(b => b.researcher === researcher);
  const researcherWeight = researcherBugs.reduce((sum, bug) => {
    const baseWeight = competitionProgram.severityWeights[bug.severity];
    // If duplicate, split weight among all finders
    const duplicateCount = allBugs.filter(b =>
      b.fingerprint === bug.fingerprint
    ).length;
    return sum + (baseWeight / duplicateCount);
  }, 0);

  // Step 3: Calculate payout
  const payout = (researcherWeight / totalWeight) * competitionProgram.totalPrizePool;

  return payout;
}

// Example scenario:
// Total pool: $100,000
// Bugs found:
//   - Alice: 1 Critical (weight: 10)
//   - Bob: 2 High (weight: 5 each = 10)
//   - Charlie: 1 Critical (duplicate with Alice, weight: 10/2 = 5)
//   - Dave: 3 Medium (weight: 2 each = 6)
// Total weight: 10 + 10 + 5 + 6 = 31
//
// Payouts:
//   - Alice: (10 / 31) * $100k = $32,258
//   - Bob: (10 / 31) * $100k = $32,258
//   - Charlie: (5 / 31) * $100k = $16,129
//   - Dave: (6 / 31) * $100k = $19,355
```

**Pros:**
- ✅ Predictable cost for projects (capped)
- ✅ Encourages thorough auditing (more bugs = more share)
- ✅ Duplicate handling built-in

**Cons:**
- ❌ Unpredictable for researchers
- ❌ Critical bug might pay less than expected if pool is small
- ❌ Competition can discourage collaboration

---

### **Model C: Hybrid (Best of Both) - RECOMMENDED FOR V2**

#### How It Works:
- Fixed tier minimums PLUS bonus pool
- Guaranteed base pay + competitive upside

#### Example Configuration:
```javascript
const hybridProgram = {
  projectName: "Cetus Protocol",
  guaranteedMinimums: {
    CRITICAL: 25000, // Guaranteed minimum
    HIGH: 10000,
    MEDIUM: 2500,
    LOW: 500
  },
  bonusPool: 50000, // Additional pool split competitively
  duration: 30 // Days for bonus pool qualification
};
```

#### Payout Calculation:
```javascript
function calculateHybridPayout(bug, allBugs, researcher) {
  // Part 1: Guaranteed minimum (paid immediately)
  const guaranteed = hybridProgram.guaranteedMinimums[bug.severity];

  // Part 2: Bonus pool share (paid at end of period)
  const bonusShare = calculateCompetitivePayout(allBugs, researcher);

  return {
    immediate: guaranteed,
    bonus: bonusShare,
    total: guaranteed + bonusShare
  };
}

// Example:
// Alice finds Critical bug
// Immediate payout: $25,000 (guaranteed)
// At end of 30 days:
//   - If only Critical: gets full bonus pool share (~$40k more)
//   - If 2 Critical found: splits bonus (~$20k more)
// Total: $25k-$65k depending on competition
```

**Pros:**
- ✅ Fair to researchers (guaranteed minimum)
- ✅ Cost-effective for projects (bonus pool capped)
- ✅ Encourages participation (upside potential)
- ✅ Rewards speed (first finder gets guaranteed amount faster)

**Cons:**
- ❌ More complex to implement
- ❌ Requires period management

---

## SuiGuard Unique Enhancements

### **1. Reputation Multiplier**
```javascript
function getReputationBonus(researcher) {
  const rep = getReputation(researcher);

  if (rep >= 10000) return 1.2; // 20% bonus (elite)
  if (rep >= 5000) return 1.15;  // 15% bonus (expert)
  if (rep >= 1000) return 1.1;   // 10% bonus (veteran)
  return 1.0; // No bonus (new)
}

// Top researchers earn more for same bug
// Critical by elite: $50k * 1.2 = $60k
// Critical by newbie: $50k * 1.0 = $50k
```

### **2. First Reporter Bonus**
```javascript
// Reward speed
function getSpeedBonus(bug, allBugs) {
  const sameBugs = allBugs.filter(b =>
    b.fingerprint === bug.fingerprint
  ).sort((a, b) => a.timestamp - b.timestamp);

  if (sameBugs[0].id === bug.id) {
    return 1.25; // 25% bonus for first to report
  }
  return 1.0;
}
```

### **3. Impact-Based Adjustment**
```javascript
// DAO can vote to adjust based on actual impact
function getImpactAdjustment(bug, daoVote) {
  // Example: Bug affects $10M TVL
  if (bug.affectedTVL > 10_000_000 && daoVote.severity === "CRITICAL") {
    return 1.5; // 50% bonus for high-impact bugs
  }
  return 1.0;
}
```

### **4. Complete Formula**
```javascript
function calculateFinalPayout(bug, researcher, program, allBugs) {
  const basePayout = program.rewardTiers[bug.severity].amount;
  const repBonus = getReputationBonus(researcher);
  const speedBonus = getSpeedBonus(bug, allBugs);
  const impactBonus = getImpactAdjustment(bug, bug.daoVote);

  return basePayout * repBonus * speedBonus * impactBonus;
}

// Example calculation:
// Base: $50,000 (Critical)
// Reputation: 1.15x (expert)
// Speed: 1.25x (first reporter)
// Impact: 1.5x (high TVL affected)
// Total: $50k * 1.15 * 1.25 * 1.5 = $107,812
```

---

## Smart Contract Implementation

### Escrow Management
```move
struct BountyProgram has key, store {
    id: UID,
    project_owner: address,
    total_escrow: Balance<SUI>,
    reserved_payouts: u64, // Amount reserved for pending bugs
    severity_tiers: VecMap<u8, u64>,
    model: u8, // FIXED_TIER or PRIZE_POOL or HYBRID
}

public fun create_fixed_tier_program(
    escrow: Coin<SUI>,
    critical_amount: u64,
    high_amount: u64,
    medium_amount: u64,
    low_amount: u64,
    ctx: &mut TxContext
): BountyProgram {
    let escrow_value = coin::value(&escrow);

    // Ensure escrow can cover at least 5 critical bugs
    assert!(escrow_value >= critical_amount * 5, E_INSUFFICIENT_ESCROW);

    let tiers = vec_map::empty();
    vec_map::insert(&mut tiers, SEVERITY_CRITICAL, critical_amount);
    vec_map::insert(&mut tiers, SEVERITY_HIGH, high_amount);
    vec_map::insert(&mut tiers, SEVERITY_MEDIUM, medium_amount);
    vec_map::insert(&mut tiers, SEVERITY_LOW, low_amount);

    BountyProgram {
        id: object::new(ctx),
        project_owner: tx_context::sender(ctx),
        total_escrow: coin::into_balance(escrow),
        reserved_payouts: 0,
        severity_tiers: tiers,
        model: MODEL_FIXED_TIER
    }
}
```

---

## Comparison Table

| Feature | Immunefi | Sherlock | Cantina | **SuiGuard** |
|---------|----------|----------|---------|--------------|
| **Model** | Fixed tier | Prize pool | Prize pool | Fixed tier + bonuses |
| **Predictability** | High | Low | Low | **Medium-High** |
| **Cost for Project** | Variable | Fixed | Fixed | **Semi-fixed** |
| **Researcher Income** | Predictable | Variable | Variable | **Guaranteed minimum** |
| **Competition** | No | Yes | Yes | **Optional** |
| **Payout Speed** | Slow (30-90 days) | Slow (post-contest) | Slow | **Instant (on-chain)** |
| **PoC Verification** | Manual review | Judge review | Judge review | **TEE-verified (Nautilus)** |
| **Disclosure** | Trust-based | Public after | Public after | **Cryptographic time-lock (Seal)** |
| **Storage** | Centralized | Centralized | Centralized | **Decentralized (Walrus)** |
| **Reputation** | Off-chain | Off-chain | Off-chain | **On-chain (SBT)** |

---

## Recommendation for Hackathon

### **Start with Model A (Fixed Tier)**
**Why:**
- ✅ Simplest to implement
- ✅ Easy to explain to judges
- ✅ Industry standard (familiar)
- ✅ Focus innovation on Nautilus/Seal/Walrus integration

### **Add Model C (Hybrid) for V2**
**Why:**
- Showcases smart contract sophistication
- Better economics for both sides
- Differentiates from competitors

### **Killer Feature: Nautilus PoC Verification**
This is what makes SuiGuard unique:
- Immunefi/Sherlock rely on human judgment
- We have cryptographic proof exploits work
- No other platform can do this

---

## Example: Full Submission Flow

```javascript
// 1. Project creates bounty program
await suiContract.createBountyProgram({
  code: uploadToWalrus("github.com/cetus/core"),
  escrow: "100000 SUI",
  tiers: {
    CRITICAL: 50000,
    HIGH: 20000,
    MEDIUM: 5000,
    LOW: 1000
  }
});

// 2. Researcher finds bug, submits to Nautilus
const attestation = await nautilus.verifyExploit(pocCode);

// 3. Encrypt report with Seal, upload to Walrus
const encrypted = await seal.encrypt(bugReport, timeLockPolicy);
const blobId = await walrus.upload(encrypted);

// 4. Submit to smart contract
await suiContract.submitBugReport({
  programId: "0x123...",
  walrusBlobId: blobId,
  nautilusAttestation: attestation,
  severity: "CRITICAL"
});

// 5. DAO votes on severity (48 hours)
// 6. Smart contract pays instantly
// Result: Researcher gets 50,000 SUI in ~3 days vs 30-90 days on other platforms
```

---

## What Makes This Win?

✅ **Faster than competitors:** Instant on-chain payouts vs 30-90 day waits
✅ **More trustworthy:** TEE-verified exploits vs human judgment
✅ **More transparent:** All payouts/reputation on-chain
✅ **More fair:** DAO voting vs centralized triage
✅ **More permanent:** Walrus storage vs deletable databases
✅ **More secure:** Seal time-locks vs trust-based disclosure

This is genuinely better than Immunefi, Sherlock, and Cantina. 🚀



sui move test 2>&1 | grep -E "(Test result:|PASS|FAIL)"