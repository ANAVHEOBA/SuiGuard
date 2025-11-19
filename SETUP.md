# SuiGuard Development Environment Setup

## Prerequisites Installation Checklist

### Required Tools:
- [ ] Sui CLI
- [ ] Rust & Cargo (for Move development)
- [ ] Node.js & npm (for frontend)
- [ ] Git
- [ ] VS Code with Move extensions (optional but recommended)

---

## 1. Install Sui CLI

### Option A: Using Install Script (Recommended)
```bash
# Download and install Sui
curl -fsSL https://sui.io/install.sh | sh
```

### Option B: Using Cargo (if you have Rust)
```bash
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch mainnet sui
```

### Option C: Using Homebrew (macOS)
```bash
brew install sui
```

### Verify Installation:
```bash
sui --version
# Should output: sui 1.x.x
```

---

## 2. Install Rust (Required for Move Development)

```bash
# Install Rust via rustup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Follow prompts, then reload shell
source $HOME/.cargo/env

# Verify
rustc --version
cargo --version
```

---

## 3. Install Node.js & npm (for Frontend)

### Using nvm (Recommended):
```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Reload shell
source ~/.bashrc

# Install Node.js LTS
nvm install --lts
nvm use --lts

# Verify
node --version
npm --version
```

### Using apt (Ubuntu/Debian):
```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
```

---

## 4. Install Git (if not already installed)

```bash
sudo apt-get update
sudo apt-get install git -y

# Verify
git --version
```

---

## 5. Configure Sui

### Initialize Sui Configuration:
```bash
# Create Sui config and generate wallet
sui client

# This will:
# 1. Create ~/.sui/sui_config directory
# 2. Generate a new wallet address
# 3. Set up network configuration
```

### Switch to Testnet:
```bash
# Add testnet
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443

# Switch to testnet
sui client switch --env testnet

# Verify current network
sui client active-env
```

### Get Testnet Tokens:
```bash
# Get your wallet address
sui client active-address

# Request testnet SUI from faucet
curl --location --request POST 'https://faucet.testnet.sui.io/gas' \
--header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "YOUR_ADDRESS_HERE"
    }
}'
```

Or use the web faucet:
- Visit: https://docs.sui.io/guides/developer/getting-started/get-address
- Connect wallet and request tokens

---

## 6. Install Move Analyzer (VS Code Extension)

### Install VS Code Extensions:
```bash
# If using VS Code
code --install-extension mysten.move
code --install-extension mysten.sui-move-analyzer
```

Or manually:
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "Move" and install:
   - Move Syntax
   - Sui Move Analyzer

---

## 7. Project Setup

### Create New Sui Move Project:
```bash
# Navigate to SuiGuard directory
cd /home/a/SuiGuard

# Create new Sui Move package
sui move new suiguard_contracts

# Project structure created:
# suiguard_contracts/
# ├── Move.toml
# └── sources/
```

### Install Frontend Dependencies:
```bash
# Create frontend directory
mkdir suiguard_frontend
cd suiguard_frontend

# Initialize npm project
npm init -y

# Install Sui SDK
npm install @mysten/sui.js @mysten/dapp-kit @tanstack/react-query

# Install React (if building UI)
npm install react react-dom next
```

---

## 8. Verify Everything Works

### Test Sui CLI:
```bash
# Check active address
sui client active-address

# Check balance
sui client gas

# List available commands
sui --help
```

### Test Move Compilation:
```bash
# Navigate to Move project
cd /home/a/SuiGuard/suiguard_contracts

# Build the package
sui move build

# Should output: Build Successful
```

---

## 9. Optional: Install Walrus CLI (When Available)

```bash
# Walrus is in beta - check official docs for install
# Typically:
npm install -g @mysten/walrus-cli

# Or download binary from:
# https://docs.walrus.site/
```

---

## 10. Optional: Set Up Nautilus (TEE)

Nautilus setup will be provided by Sui Foundation during hackathon:
- Check: https://docs.sui.io/guides/developer/advanced/secure-enclave
- Follow hackathon-specific instructions

---

## Quick Start After Setup

### 1. Create Your First Move Module:
```bash
cd /home/a/SuiGuard/suiguard_contracts/sources
touch bounty_program.move
```

### 2. Write Smart Contract:
```move
module suiguard::bounty_program {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    struct BountyProgram has key {
        id: UID,
        name: vector<u8>
    }

    public fun create(name: vector<u8>, ctx: &mut TxContext): BountyProgram {
        BountyProgram {
            id: object::new(ctx),
            name
        }
    }
}
```

### 3. Build:
```bash
sui move build
```

### 4. Test:
```bash
sui move test
```

### 5. Deploy to Testnet:
```bash
sui client publish --gas-budget 100000000
```

---

## Troubleshooting

### Issue: "sui: command not found"
```bash
# Add to PATH
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: "Cannot connect to network"
```bash
# Check network config
cat ~/.sui/sui_config/client.yaml

# Reset network
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
sui client switch --env testnet
```

### Issue: "Insufficient gas"
```bash
# Request more testnet tokens
sui client faucet
```

---

## Useful Commands Reference

```bash
# Wallet Management
sui client active-address          # Show current address
sui client addresses               # List all addresses
sui client new-address ed25519     # Create new address
sui client switch --address <ADDR> # Switch active address

# Network Management
sui client envs                    # List networks
sui client switch --env testnet    # Switch network

# Move Development
sui move build                     # Compile contracts
sui move test                      # Run tests
sui move prove                     # Formal verification

# Deployment
sui client publish --gas-budget 100000000

# Object Inspection
sui client object <OBJECT_ID>      # View object details
sui client objects                 # List owned objects

# Transaction History
sui client transactions            # View recent transactions
```

---

## Next Steps

1. ✅ Install all tools (use commands below)
2. ✅ Create Sui wallet and get testnet tokens
3. ✅ Build first Move contract
4. ✅ Start building SuiGuard features
5. ✅ Integrate Walrus/Seal/Nautilus

Ready to start? Run the installation commands and we'll build together! 🚀
