# ERC20 Token on Base

An ERC20 token deployed on [Base](https://base.org) — Ethereum L2 by Coinbase.

## Features

- ✅ ERC20 standard (transfer, approve, allowance)
- 🔥 Burnable — token holders can burn their tokens
- 🪙 Mintable — owner can mint up to max supply
- 🔒 Max supply cap of 1,000,000,000 tokens
- 👤 Ownable — mint function restricted to owner

## Contract

Built with [Foundry](https://book.getfoundry.sh/) and [OpenZeppelin](https://openzeppelin.com/contracts/).

## Setup

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install dependencies
forge install OpenZeppelin/openzeppelin-contracts

# Copy env file
cp .env.example .env
# Fill in your PRIVATE_KEY and BASESCAN_API_KEY
```

## Test

```bash
forge test
```

## Deploy to Base

```bash
forge script script/Deploy.s.sol \
  --rpc-url base \
  --broadcast \
  --verify
```

## Deploy to Base Sepolia (testnet)

```bash
forge script script/Deploy.s.sol \
  --rpc-url base_sepolia \
  --broadcast \
  --verify
```

## Network

- **Base Mainnet:** https://mainnet.base.org (Chain ID: 8453)
- **Base Sepolia:** https://sepolia.base.org (Chain ID: 84532)
- **Explorer:** https://basescan.org
