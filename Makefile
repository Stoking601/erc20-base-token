.PHONY: test build fmt clean

test:
	forge test -v

build:
	forge build

fmt:
	forge fmt

clean:
	forge clean

deploy-testnet:
	forge script script/DeployAll.s.sol --rpc-url base_sepolia --broadcast --verify

deploy-mainnet:
	forge script script/DeployAll.s.sol --rpc-url base --broadcast --verify
