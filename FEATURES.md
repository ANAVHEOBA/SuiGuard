# SuiGuard Smart Contract Features

## Complete Feature List - Start to Finish

---

## Phase 1: Core Infrastructure

### 1.1 Bounty Program Management

#### Feature: Create Bounty Program
- **What:** Projects can create bug bounty programs with escrowed funds
- **Requirements:**
  - Accept SUI/USDC as escrow currency
  - Define severity tiers (Critical, High, Medium, Low, Informational)
  - Set payout amounts per severity level
  - Store program details on Walrus (scope, rules, contact info)
  - Set program expiry date
  - Minimum escrow amount validation
- **Smart Contract Functions:**
  - `create_bounty_program()`
  - `fund_bounty_program()` - add more funds
  - `update_severity_tiers()`
  - `pause_program()` / `resume_program()`

#### Feature: Bounty Program Discovery
- **What:** List all active bounty programs
- **Requirements:**
  - Query active programs by TVL (total value locked)
  - Filter by payout range
  - Search by project name
  - View program statistics (bugs found, payouts made)
- **Smart Contract Functions:**
  - `get_all_programs()`
  - `get_program_stats()`

---

### 1.2 Bug Report Submission

#### Feature: Submit Encrypted Bug Report
- **What:** Researchers submit encrypted vulnerability reports
- **Requirements:**
  - Upload encrypted report to Walrus
  - Generate Seal policy for time-locked disclosure (90 days default)
  - Include vulnerability category (reentrancy, overflow, logic error, etc.)
  - Attach affected contract addresses/modules
  - Anti-spam: small submission fee (refunded if valid)
  - Store Walrus blob ID on-chain
- **Smart Contract Functions:**
  - `submit_bug_report()`
  - `withdraw_report()` - researcher can retract before verification

#### Feature: Duplicate Detection
- **What:** Prevent duplicate bug submissions
- **Requirements:**
  - Hash of vulnerability signature (contract + function + type)
  - Check against existing reports for same program
  - If duplicate: reject or merge with original
  - Reward original reporter, not duplicates
- **Smart Contract Functions:**
  - `check_duplicate()`
  - `mark_as_duplicate()`

---

### 1.3 Nautilus TEE Verification

#### Feature: Submit Proof-of-Concept Attestation
- **What:** Researcher proves exploit works via Nautilus TEE
- **Requirements:**
  - Accept attestation data from Nautilus enclave
  - Verify SGX/TDX signature on-chain
  - Validate enclave measurement (ensure legitimate Nautilus instance)
  - Store attestation result (exploit confirmed: true/false)
  - Timestamp verification
  - Link attestation to specific bug report
- **Smart Contract Functions:**
  - `submit_attestation()`
  - `verify_sgx_signature()`
  - `validate_enclave_measurement()`

#### Feature: Attestation Validation
- **What:** Ensure only valid TEE attestations are accepted
- **Requirements:**
  - Whitelist of trusted Nautilus enclave measurements
  - Signature verification using public key cryptography
  - Replay attack prevention (nonce/timestamp check)
  - Reject attestations older than 24 hours
- **Smart Contract Functions:**
  - `add_trusted_enclave()`
  - `revoke_enclave()`

---

## Phase 2: Triage & Validation

### 2.1 DAO-Based Severity Triage

#### Feature: Community Triage Voting
- **What:** Stakers vote on bug severity to reach consensus
- **Requirements:**
  - Stake SUI tokens to vote
  - Vote on severity level (Critical/High/Medium/Low/Invalid)
  - Voting period: 48 hours
  - Minimum quorum required (e.g., 10,000 SUI staked)
  - Weighted voting by stake amount
  - Slash stakes of minority voters (incentivize honest voting)
  - Reward majority voters with portion of slashed stakes
- **Smart Contract Functions:**
  - `create_triage_vote()`
  - `cast_vote()`
  - `finalize_triage()`
  - `claim_voting_rewards()`

#### Feature: Rapid Response for Critical Bugs
- **What:** Fast-track verification for time-sensitive exploits
- **Requirements:**
  - Project can pay premium for expedited triage (6-hour voting)
  - Higher staking requirements for fast-track votes
  - Emergency DAO multisig can fast-track if active exploit detected
- **Smart Contract Functions:**
  - `create_urgent_triage()`
  - `emergency_fast_track()`

---

### 2.2 Project Review & Response

#### Feature: Project Access to Encrypted Reports
- **What:** Project can decrypt and review bug details via Seal
- **Requirements:**
  - Seal policy grants access to project owner
  - Project can acknowledge receipt
  - Project can request additional info from researcher
  - Project can dispute severity (triggers DAO vote)
- **Smart Contract Functions:**
  - `acknowledge_report()`
  - `request_clarification()`
  - `dispute_severity()`

#### Feature: Fix Verification
- **What:** Project proves vulnerability was patched
- **Requirements:**
  - Project submits fix commit hash or upgraded package ID
  - Optional: re-run PoC in Nautilus to confirm fix
  - Set fix deployment timestamp
- **Smart Contract Functions:**
  - `submit_fix()`
  - `verify_fix_with_nautilus()`

---

## Phase 3: Payouts & Rewards

### 3.1 Automated Payouts

#### Feature: Instant Escrow Release
- **What:** Automatic payout after triage finalization
- **Requirements:**
  - Release funds from bounty program escrow
  - Transfer exact severity tier amount to researcher
  - Support SUI and USDC payouts
  - Emit payout event with metadata
  - Update program's remaining escrow balance
- **Smart Contract Functions:**
  - `execute_payout()`
  - `claim_payout()` - if pull payment pattern used

#### Feature: Bounty Splitting
- **What:** Split rewards among multiple researchers
- **Requirements:**
  - Primary researcher can designate co-finders
  - Define percentage splits
  - All parties must sign off
  - Atomic multi-transfer
- **Smart Contract Functions:**
  - `propose_split()`
  - `approve_split()`
  - `execute_split_payout()`

---

### 3.2 Reputation System

#### Feature: Whitehat Reputation Tracking
- **What:** On-chain reputation score for researchers
- **Requirements:**
  - Track total bugs found per severity
  - Track total earnings
  - Calculate reputation score:
    - `score = (Critical * 1000) + (High * 500) + (Medium * 100) + (Low * 10)`
  - Reputation affects future payout multipliers (e.g., 1.1x for top researchers)
  - Display as profile object
- **Smart Contract Functions:**
  - `update_reputation()`
  - `get_researcher_stats()`
  - `calculate_reputation_bonus()`

#### Feature: Achievement NFTs
- **What:** Award badge NFTs for milestones
- **Requirements:**
  - "First Blood" - first bug found
  - "Critical Hunter" - found 5 critical bugs
  - "Millionaire" - earned 1M SUI in bounties
  - "Specialist" badges for bug categories (reentrancy expert, etc.)
  - Non-transferable soulbound tokens
- **Smart Contract Functions:**
  - `mint_achievement_badge()`
  - `check_achievement_eligibility()`

---

## Phase 4: Time-Locked Disclosure (Seal Integration)

### 4.1 Responsible Disclosure Timeline

#### Feature: 90-Day Auto-Disclosure
- **What:** Bug reports automatically become public after 90 days
- **Requirements:**
  - Seal policy enforces time-lock
  - Policy allows decryption by:
    - Researcher (always)
    - Project (always, until they fix it)
    - Public (after 90 days OR after fix deployed)
  - Store disclosure deadline on-chain
  - Emit event when disclosure time reached
- **Smart Contract Functions:**
  - `check_disclosure_status()`
  - `trigger_public_disclosure()` - callable after 90 days

#### Feature: Early Disclosure for Fixed Bugs
- **What:** Project can make report public early if already fixed
- **Requirements:**
  - Project must prove fix deployed (package upgrade or commit)
  - Researcher must approve early disclosure
  - Update Seal policy to allow public access
- **Smart Contract Functions:**
  - `request_early_disclosure()`
  - `approve_early_disclosure()`

---

## Phase 5: Historical Data & Analytics

### 5.1 Vulnerability Database

#### Feature: Walrus-Backed Audit Archive
- **What:** Permanent storage of all bug reports and audit reports
- **Requirements:**
  - Store every finalized report on Walrus
  - Tag by vulnerability type (CWE classification)
  - Tag by affected Move modules/functions
  - Full-text search capability
  - Link to related bugs (same vulnerability pattern)
- **Smart Contract Functions:**
  - `archive_report()`
  - `query_by_cwe_type()`
  - `get_related_bugs()`

#### Feature: Exploit Pattern Recognition
- **What:** ML-powered similar bug detection
- **Requirements:**
  - Off-chain indexer analyzes all reports
  - Generate vulnerability fingerprints
  - Alert projects if similar bug found elsewhere
  - Suggest potential vulnerabilities based on code patterns
- **Integration:** Off-chain service, but results stored on-chain

---

### 5.2 Platform Statistics

#### Feature: Security Dashboard
- **What:** Public metrics on Sui ecosystem security
- **Requirements:**
  - Total TVL in bounty programs
  - Total payouts made
  - Average response time (submission to payout)
  - Most common vulnerability types
  - Top researchers leaderboard
  - Most secure projects (by bugs found vs TVL)
- **Smart Contract Functions:**
  - `get_platform_stats()`
  - `get_leaderboard()`

---

## Phase 6: Advanced Features

### 6.1 Bounty Matching Pool

#### Feature: Community Top-Up Rewards
- **What:** Community can add funds to bounties for critical infrastructure
- **Requirements:**
  - Anyone can donate to a bounty pool
  - Donations distributed proportionally to severity tiers
  - Donors receive "Security Supporter" NFTs
  - Transparent tracking of community contributions
- **Smart Contract Functions:**
  - `contribute_to_bounty()`
  - `get_contribution_stats()`

---

### 6.2 Multi-Sig Project Management

#### Feature: Team-Based Program Management
- **What:** Projects can use multi-sig for bounty program control
- **Requirements:**
  - Support N-of-M signatures for:
    - Funding additions
    - Severity tier changes
    - Report acknowledgments
    - Fix verifications
  - Integration with existing Sui multi-sig wallets
- **Smart Contract Functions:**
  - `create_multisig_program()`
  - `multisig_approve_action()`

---

### 6.3 Appeal & Dispute Resolution

#### Feature: Two-Tier Dispute System
- **What:** Handle disagreements between researchers and projects
- **Requirements:**
  - **Tier 1:** DAO re-vote with higher quorum
  - **Tier 2:** Expert council (appointed security auditors)
  - Dispute must be filed within 7 days of triage
  - Loser pays dispute fee
- **Smart Contract Functions:**
  - `file_dispute()`
  - `resolve_dispute()`

---

### 6.4 Subscription Programs

#### Feature: Ongoing Security Monitoring
- **What:** Projects pay monthly for continuous coverage
- **Requirements:**
  - Recurring payments from project treasury
  - Auto-refill escrow when below threshold
  - Researchers get bonus for subscribed programs
  - Cancel anytime, unused funds returned
- **Smart Contract Functions:**
  - `create_subscription_program()`
  - `process_recurring_payment()`
  - `cancel_subscription()`

---

## Phase 7: Integrations & Ecosystem

### 7.1 DeFi Protocol Integrations

#### Feature: Auto-Pause on Critical Bugs
- **What:** Integrate with DeFi protocols to auto-pause on critical findings
- **Requirements:**
  - Protocol grants SuiGuard emergency pause permission
  - If critical bug verified via Nautilus + DAO, trigger pause
  - Protocol has 24 hours to review before public disclosure
  - Prevents exploits during disclosure period
- **Smart Contract Functions:**
  - `grant_emergency_pause_permission()`
  - `trigger_emergency_pause()`

---

### 7.2 Audit Firm Partnerships

#### Feature: Professional Auditor Participation
- **What:** Audit firms can verify and triage bugs
- **Requirements:**
  - Verified auditor status (KYC'd entities)
  - Higher weight in DAO votes
  - Can fast-track obvious bugs
  - Earn fees for triage work
- **Smart Contract Functions:**
  - `register_auditor()`
  - `auditor_verify_report()`

---

## Security & Safety Features

### Access Control
- Role-based permissions (project owner, researcher, validator, admin)
- Time-locks on critical functions (escrow withdrawal)
- Emergency pause for entire platform
- Upgrade mechanisms with time-delay

### Anti-Abuse
- Rate limiting on submissions per researcher
- Deposit requirements that scale with reputation
- Duplicate detection
- Spam filtering via staking requirements

### Fund Safety
- Escrow held in isolated objects per program
- Multi-sig for platform treasury
- No admin access to escrowed bounty funds
- Automatic refunds if program expires

---

## Implementation Checklist

### MVP (Minimum Viable Product)
- [ ] Bounty program creation with escrow
- [ ] Bug report submission with Walrus storage
- [ ] Nautilus attestation verification
- [ ] Basic DAO triage voting
- [ ] Automated payouts
- [ ] Seal time-locked disclosure (90 days)
- [ ] Basic reputation tracking

### V1.0 Launch
- [ ] Achievement NFTs
- [ ] Duplicate detection
- [ ] Fix verification
- [ ] Platform statistics dashboard
- [ ] Multi-sig support
- [ ] Bounty matching pool

### V2.0 Advanced
- [ ] ML pattern recognition
- [ ] Subscription programs
- [ ] DeFi protocol integrations
- [ ] Professional auditor tier
- [ ] Dispute resolution system

---

## Success Metrics

### Platform Health
- Total bounties created
- Average time to triage
- Average time to payout
- Researcher retention rate

### Security Impact
- Vulnerabilities prevented
- Funds secured (TVL of protected projects)
- Comparison to traditional audit costs

### Ecosystem Adoption
- Number of Sui projects with active bounties
- Total researcher accounts
- DAO participation rate
