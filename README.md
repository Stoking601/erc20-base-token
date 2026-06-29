# ERC20 Token Suite on Base

A complete ERC20 ecosystem on [Base](https://base.org).

## Contracts

| Contract | Description |
|---|---|
| MyToken | ERC20 with mint, burn, pause |
| TokenVesting | Linear vesting with revoke |
| TokenAirdrop | Batch distribution |
| TokenSale | ETH presale |
| TokenTimeLock | Time-locked release |

## Stack
- [Foundry](https://book.getfoundry.sh/)
- [OpenZeppelin](https://openzeppelin.com/contracts/)
- Base (Chain ID: 8453)

## Setup
```
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge install OpenZeppelin/openzeppelin-contracts
cp .env.example .env
```

## Test
```
forge test -v
```

## Deploy
```
forge script script/DeployAll.s.sol --rpc-url base_sepolia --broadcast --verify
```

## Docs
- [Architecture](docs/architecture.md)
- [Tokenomics](docs/tokenomics.md)
- [Security](docs/security.md)
- [Roadmap](docs/roadmap.md)
- [FAQ](docs/faq.md)

## Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md)

## License
MIT
