# SuiGuard

**Decentralized Bug Bounty Platform for the Sui Ecosystem**

> Built for Walrus Haulout Hackathon (Nov 6-16, 2025)

---

## 🎯 Problem

The $260M Cetus hack (May 2025) and $2.4M Nemo Protocol hack (Sept 2025) exposed critical gaps in smart contract security:
- Traditional audits miss vulnerabilities
- Bug bounty platforms are centralized and slow
- No way to verify exploits without risking mainnet
- Disclosure timelines depend on trust, not cryptography

**Sui Foundation committed $10M to bug bounties** - but the infrastructure is missing.

---

## 💡 Solution: SuiGuard

The first **fully decentralized, trustless bug bounty platform** with:

### 🔐 **Verifiable Proof-of-Concept (Nautilus)**
- Researchers prove exploits work in TEE (Trusted Execution Environment)
- Cryptographic attestation that bug is real
- No risk to mainnet, no trust required

### ⏰ **Time-Locked Disclosure (Seal)**
- 90-day responsible disclosure enforced cryptographically
- Multi-party access control (researcher + project)
- Automatic public disclosure if unfixed

### 📦 **Permanent Audit Archive (Walrus)**
- Every bug report stored permanently
- Censorship-resistant vulnerability database
- Historical data for pattern recognition

### ⚡ **Instant On-Chain Payouts (Sui)**
- Smart contract escrow and automated payments
- DAO-based severity triage
- Reputation system with achievement NFTs

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  SuiGuard Platform                       │
└─────────────────────┬───────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┬──────────────┐
        │             │             │              │
        ▼             ▼             ▼              ▼
┌──────────┐  ┌──────────────┐  ┌──────┐  ┌──────────────┐
│   Sui    │  │   Walrus     │  │ Seal │  │  Nautilus    │
│Contracts │  │   Storage    │  │Access│  │     TEE      │
└──────────┘  └──────────────┘  └──────┘  └──────────────┘
```

---

## 📋 Features

### For Projects:
- ✅ Create bounty programs with SUI/USDC escrow
- ✅ Set severity-based payout tiers
- ✅ Access TEE-verified exploit proofs
- ✅ Time-locked disclosure (90 days to fix)
- ✅ Permanent audit trail on Walrus

### For Researchers:
- ✅ Submit encrypted bug reports
- ✅ Prove exploits in isolated Nautilus environment
- ✅ Build on-chain reputation
- ✅ Earn instant payouts via smart contracts
- ✅ Earn achievement NFTs

### For Ecosystem:
- ✅ DAO voting on bug severity
- ✅ Transparent triage process
- ✅ Public security statistics
- ✅ Searchable vulnerability database

---

## 🚀 Tech Stack

| Technology | Purpose |
|------------|---------|
| **Sui Move** | Smart contracts (escrow, voting, payouts) |
| **Walrus** | Decentralized storage for bug reports & audits |
| **Seal** | Policy-based access control & time-locks |
| **Nautilus** | TEE for verifiable PoC execution |
| **React + Sui SDK** | Frontend dApp |

---

## 📂 Project Structure

```
SuiGuard/
├── README.md                  # This file
├── FEATURES.md                # Complete feature specification
├── TOOLS.md                   # Technology stack details
├── REWARD_MECHANISM.md        # Payout calculation models
├── SETUP.md                   # Development environment setup
├── contracts/                 # Sui Move smart contracts
│   ├── sources/
│   │   ├── bounty_program.move
│   │   ├── bug_report.move
│   │   ├── reputation.move
│   │   ├── triage_dao.move
│   │   └── nautilus_verifier.move
│   ├── tests/
│   └── Move.toml
├── frontend/                  # React dApp
│   ├── src/
│   ├── public/
│   └── package.json
└── docs/                      # Additional documentation
```

---

## 🎮 How It Works

### 1. Project Creates Bounty
```javascript
createBountyProgram({
  code: uploadToWalrus("github.com/project/contracts"),
  escrow: "100,000 SUI",
  rewards: {
    Critical: 50000,
    High: 20000,
    Medium: 5000,
    Low: 1000
  }
});
```

### 2. Researcher Finds Bug
```javascript
// Run exploit in Nautilus TEE
const attestation = await nautilus.verifyExploit(pocCode);

// Encrypt report with Seal policy
const encrypted = await seal.encrypt(report, timeLockPolicy);

// Upload to Walrus
const blobId = await walrus.upload(encrypted);

// Submit on-chain
await submitBugReport(blobId, attestation);
```

### 3. DAO Triages & Smart Contract Pays
```javascript
// Community votes on severity (48 hours)
await castTriageVote(reportId, "CRITICAL", 1000); // Stake 1000 SUI

// After consensus, instant payout
// Researcher receives 50,000 SUI automatically
```

### 4. Time-Locked Disclosure
```
Day 0-90: Only project can decrypt (via Seal)
Day 90+:  Report becomes public automatically
          OR earlier if project deploys fix
```

---

## 🏆 Competitive Advantages

| Feature | Immunefi | Sherlock | **SuiGuard** |
|---------|----------|----------|--------------|
| **Payout Speed** | 30-90 days | Post-contest | **Instant** |
| **PoC Verification** | Manual review | Judge review | **TEE-verified** |
| **Disclosure** | Trust-based | Trust-based | **Crypto time-lock** |
| **Storage** | Centralized | Centralized | **Decentralized** |
| **Triage** | Centralized | Centralized | **DAO voting** |
| **Reputation** | Off-chain | Off-chain | **On-chain SBT** |

---

## 📊 Success Metrics

### Platform Health:
- Total bounties created
- Average time to triage (target: <48 hours)
- Average time to payout (target: <72 hours)
- Researcher retention rate

### Security Impact:
- Vulnerabilities prevented
- Funds secured (TVL of protected projects)
- Cost savings vs traditional audits

### Ecosystem Adoption:
- Number of Sui projects with active bounties
- Total whitehat researcher accounts
- DAO participation rate

---

## 🛣️ Roadmap

### Phase 1: MVP (Hackathon - Nov 16)
- [x] Project documentation
- [ ] Core smart contracts
  - [ ] Bounty program creation
  - [ ] Bug report submission
  - [ ] Nautilus attestation verification
  - [ ] DAO triage voting
  - [ ] Automated payouts
- [ ] Walrus integration (encrypted storage)
- [ ] Seal integration (time-locked access)
- [ ] Basic frontend
- [ ] Demo video

### Phase 2: V1.0 Launch (Post-Hackathon)
- [ ] Achievement NFT system
- [ ] Duplicate detection
- [ ] Fix verification
- [ ] Platform statistics dashboard
- [ ] Multi-sig program management
- [ ] Bounty matching pool

### Phase 3: V2.0 Advanced
- [ ] ML pattern recognition for similar bugs
- [ ] Subscription-based programs
- [ ] DeFi protocol integrations (auto-pause)
- [ ] Professional auditor tier
- [ ] Dispute resolution system

---

## 💰 Tokenomics (Future)

### Platform Revenue:
- 2% fee on all payouts (sustainable funding)
- Grant from Sui Foundation
- Community treasury for public goods

### $GUARD Token (Potential):
- Governance over platform parameters
- Staking for DAO voting weight
- Fee discounts for projects
- Reputation boosts for researchers

---

## 🤝 Team

**Solo Builder** (for hackathon)
- Smart contract development
- Walrus/Seal/Nautilus integration
- Frontend development

**Future Team Needs:**
- Security researchers (beta testers)
- Marketing & BD (project outreach)
- Full-stack engineers (scaling)

---

## 📚 Resources

### Documentation:
- [Complete Feature List](./FEATURES.md)
- [Technology Stack](./TOOLS.md)
- [Reward Mechanisms](./REWARD_MECHANISM.md)
- [Setup Guide](./SETUP.md)

### External Links:
- Sui Documentation: https://docs.sui.io
- Walrus Docs: https://docs.walrus.site
- Nautilus Guide: https://docs.sui.io/guides/developer/cryptography
- Hackathon Details: https://sui.io/haulout

---

## 🎯 Why This Will Win

### 1. **Timely & Strategic**
- Sui Foundation just committed $10M to bug bounties
- Recent $260M+ in hacks prove need
- Perfect timing for this infrastructure

### 2. **Technically Novel**
- Only platform with TEE-verified exploits
- Cryptographic disclosure vs trust-based
- First fully decentralized bug bounty system

### 3. **Full Stack Integration**
- Uses **all 3** required technologies (Walrus, Seal, Nautilus)
- Each serves a unique, critical purpose
- Not just a "checkbox" integration

### 4. **Real Problem, Real Solution**
- Addresses actual pain points in current systems
- Better than Immunefi, Sherlock, Code4rena
- Projects will want to use this

### 5. **Sustainable Business Model**
- 2% platform fee = recurring revenue
- Network effects (more projects = more researchers = more bugs found)
- Potential for Sui Foundation grants

---

## 📞 Contact

- GitHub: [Your GitHub]
- Twitter: [Your Twitter]
- Email: [Your Email]

---

## 📄 License

MIT License (or your preferred license)

---

**Built with ❤️ for the Sui ecosystem**

*Making DeFi safer, one bug at a time* 🛡️
