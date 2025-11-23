# SuiGuard Deployment Summary

**Date:** 2025-11-23
**Network:** Sui Testnet
**Deployer:** `0xa85516a9b5ac7ab09f02b18639b8d3e07d8d3440a05babea4968b031076f2abe`

---

## Latest Deployment

### SuiGuard Main Package

**Package ID:** `0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802`
**UpgradeCap:** `0x335308317122ab7b531de93d7fcb48a6582b49521bdee18d50c4741df73d512c`
**Version:** 1
**Previous Package ID:** `0x6d0b40c211463251e6ef066bb45988472d2005424eb403c4e06f6c0986642b89` (Devnet - Deprecated)
**Size:** ~82 KB
**Modules:** 47
**Gas Used:** ~0.71 SUI

**Includes:**
- ✅ Bounty Program Management (with updated validation)
- ✅ Bug Report Submission
- ✅ Triage & Voting
- ✅ Reputation System
- ✅ Payout Distribution
- ✅ Disclosure Management
- ✅ Archive System
- ✅ Nautilus Integration
- ✅ Statistics & Leaderboard
- ✅ Walrus & Seal Integration

**Key Updates:**
- ✨ **NEW**: Minimum escrow reduced to **0.1 SUI** (for testnet ease of use)
- ✨ **NEW**: Escrow must cover critical tier payout amount
- ✨ **NEW**: Validation: `escrow >= max(0.1 SUI, critical_amount)`

### Package 2: SuiGuard Communications Package

**Package ID:** `0xd39ed27538e866ae51985701e88417b70bea9756bab5d59c622083db84bda80a`
**UpgradeCap:** `0xd1b2b891e33af1d0cb643de52c4797da04cd8d19a0dc89747273b83945ed27fd`
**Version:** 1
**Previous Package ID:** `0x5a9602eb8e40a944b039e5fecc416ed3717e6d83facdcb868cf399843777ff83` (Devnet - Deprecated)
**Size:** ~17 KB
**Modules:** 10
**Gas Used:** ~0.17 SUI

**Includes:**
- ✅ Messaging System (Direct & Group Conversations)
- ✅ Forum System (Categories, Posts, Replies, Voting)
- ✅ Reputation Integration for Forum Gating
- ✅ Walrus Storage for Messages/Posts
- ✅ Seal Protocol Support for Encrypted Messaging

---

## Shared Objects

⚠️ **Note:** Shared objects are created during package initialization. To obtain these object IDs:

1. **View deployment transaction** on Sui Explorer to find created objects
2. **Query package events** for initialization events
3. **Use first interaction** - object IDs will be visible in transaction results

**Sui Explorer (Testnet):**
- Main Package: https://testnet.suivision.xyz/package/0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802
- Communications: https://testnet.suivision.xyz/package/0xd39ed27538e866ae51985701e88417b70bea9756bab5d59c622083db84bda80a

### Main Package Objects

| Object | Type | Object ID |
|--------|------|-----------|
| **BountyRegistry (ProgramRegistry)** | `suiguard::bounty_registry::ProgramRegistry` | *Obtain from init tx* |
| **TriageRegistry** | `suiguard::triage_types::TriageRegistry` | *Obtain from init tx* |
| **DuplicateRegistry** | `suiguard::duplicate_registry::DuplicateRegistry` | *Obtain from init tx* |
| **ArchiveRegistry** | `suiguard::archive_types::ArchiveRegistry` | *Obtain from init tx* |
| **Leaderboard** | `suiguard::statistics_types::Leaderboard` | *Obtain from init tx* |
| **NautilusRegistry** | `suiguard::nautilus_registry::EnclaveRegistry` | *Obtain from init tx* |
| **PlatformStatistics** | `suiguard::statistics_types::PlatformStatistics` | *Obtain from init tx* |

### Communications Package Objects

| Object | Type | Object ID |
|--------|------|-----------|
| **ConversationRegistry** | `suiguard_communications::messaging_types::ConversationRegistry` | *Obtain from init tx* |
| **ForumRegistry** | `suiguard_communications::forum_types::ForumRegistry` | *Obtain from init tx* |

### Upgrade Capabilities (Owned)

| Package | UpgradeCap ID |
|---------|---------------|
| **Main Package** | `0x335308317122ab7b531de93d7fcb48a6582b49521bdee18d50c4741df73d512c` |
| **Communications** | `0xd1b2b891e33af1d0cb643de52c4797da04cd8d19a0dc89747273b83945ed27fd` |

### Admin Capabilities (Owned)

| Capability | Object ID |
|------------|-----------|
| **Nautilus AdminCap** | `0x50e62a5675ac97606914917ed6cfec86cdb3a34157cf392eb65f5350e40ce2bb` |
| **Triage EmergencyAdminCap** | `0xdfb755250089549e951dca1eaf5ae100f90ed84968b8ea35ed015126f182e993` |

---

## Total Deployment Cost

- **Main Package:** ~0.71 SUI (Storage: 0.703965200 SUI, Compute: 0.007 SUI)
- **Communications Package:** ~0.17 SUI (Storage: 0.173143200 SUI, Compute: 0.002 SUI)
- **Total:** ~0.88 SUI

---

## Migration Notes

### For Frontend Developers

**IMPORTANT:** Deployed to **Testnet** (previously on Devnet). All IDs have changed.

1. **Update Main Package ID** to `0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802`

2. **Update Communications Package ID** to `0xd39ed27538e866ae51985701e88417b70bea9756bab5d59c622083db84bda80a`

3. **Update Network** - Switch from Devnet to **Testnet**
   - RPC URL: `https://fullnode.testnet.sui.io`
   - Explorer: `https://testnet.suivision.xyz` or `https://suiscan.xyz/testnet`

4. **Update ALL Shared Object IDs** - Obtain from deployment transaction:
   - Main Package: BountyRegistry, TriageRegistry, DuplicateRegistry, ArchiveRegistry, Leaderboard, NautilusRegistry, PlatformStatistics
   - Communications: ConversationRegistry, ForumRegistry

5. **Update Constants:**
   - **Minimum Bounty Escrow:** 0.1 SUI (100_000_000 MIST) - **reduced from 10 SUI**
   - Minimum Payout: 1 SUI (unchanged)

6. **Updated Documentation:**
   - Main package: `FRONTEND_INTEGRATION.md`
   - Testnet-specific: `TESTNET_DEPLOYMENT.md`

### What Changed

- **Network**: Moved from Devnet to Testnet
- **Minimum Escrow**: Reduced from 10 SUI to 0.1 SUI (for easier testing)
- **Package IDs**: All new package IDs and object IDs
- **Module structure**: Unchanged - same function signatures
- **Transaction structure**: Unchanged - only IDs need updating

---

## Testing Checklist

- [x] Main package builds under 100 KB limit
- [x] Communications package builds successfully
- [x] Main package deployed to testnet successfully
- [x] Communications package deployed to testnet successfully
- [x] All shared objects created (obtain IDs from init tx)
- [x] UpgradeCaps secured
- [x] Documentation updated
- [ ] Shared object IDs documented (after first interaction)
- [ ] Test bounty creation with 0.1 SUI minimum
- [ ] Test bug report submission
- [ ] Test all core functionality on testnet

---

## Explorer Links

**Sui Explorer (Testnet):**

- **Main Package:** https://testnet.suivision.xyz/package/0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802
- **Communications Package:** https://testnet.suivision.xyz/package/0xd39ed27538e866ae51985701e88417b70bea9756bab5d59c622083db84bda80a

**SuiScan (Testnet):**

- **Main Package:** https://suiscan.xyz/testnet/object/0x8feb35e2c1f3835a795d9d227cfd2b08042c4118b437b53a183037fee974f802
- **Communications Package:** https://suiscan.xyz/testnet/object/0xd39ed27538e866ae51985701e88417b70bea9756bab5d59c622083db84bda80a

---

## Next Steps

1. **Obtain Shared Object IDs** - Check deployment transaction or make first contract call
2. **Update frontend** to use new testnet package IDs and network
3. **Update constants** - Minimum bounty is now 0.1 SUI (not 10 SUI)
4. **Test bounty creation** with reduced 0.1 SUI minimum
5. **Test messaging & forum** functionality
6. **Verify all events** are emitting correctly
7. **Update any hardcoded** package IDs in tests
8. **Get testnet SUI** from faucet for testing: https://faucet.sui.io

---

**Deployment Status:** ✅ **SUCCESSFUL ON TESTNET**
