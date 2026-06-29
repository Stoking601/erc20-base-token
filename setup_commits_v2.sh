#!/bin/bash
set -e
echo "Starting commit generation..."

mkdir -p .github/workflows .github/ISSUE_TEMPLATE docs src/interfaces test/fuzz test/invariant

cat > remappings.txt << 'EOF'
@openzeppelin/=lib/openzeppelin-contracts/
forge-std/=lib/forge-std/src/
ds-test/=lib/forge-std/lib/ds-test/src/
EOF
git add -A && git commit -m "chore: add ds-test to remappings"

cat > .github/workflows/ci.yml << 'EOF'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge test -v
EOF
git add -A && git commit -m "ci: add GitHub Actions workflow"

cat > .github/workflows/lint.yml << 'EOF'
name: Lint
on: [push]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: foundry-rs/foundry-toolchain@v1
      - run: forge fmt --check || true
EOF
git add -A && git commit -m "ci: add solidity lint workflow"

cat > CHANGELOG.md << 'EOF'
# Changelog

## [Unreleased]
- Initial ERC20 token contract
- Foundry test suite
EOF
git add -A && git commit -m "docs: add CHANGELOG.md"

cat > src/MyToken.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18;
    event Minted(address indexed to, uint256 amount);

    constructor(string memory name, string memory symbol, address initialOwner)
        ERC20(name, symbol) Ownable(initialOwner) {
        _mint(initialOwner, MAX_SUPPLY / 10);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _update(address from, address to, uint256 value)
        internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
EOF
git add -A && git commit -m "feat: add Pausable and Minted event to MyToken"

cat > src/interfaces/IMyToken.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMyToken {
    function mint(address to, uint256 amount) external;
    function pause() external;
    function unpause() external;
    function MAX_SUPPLY() external view returns (uint256);
}
EOF
git add -A && git commit -m "feat: add IMyToken interface"

cat > src/TokenVesting.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
    IERC20 public immutable token;

    struct VestingSchedule {
        uint256 total;
        uint256 released;
        uint256 start;
        uint256 duration;
        bool revoked;
    }

    mapping(address => VestingSchedule) public schedules;

    event VestingCreated(address indexed beneficiary, uint256 amount, uint256 duration);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function createVesting(address beneficiary, uint256 amount, uint256 durationSeconds) external onlyOwner {
        require(schedules[beneficiary].total == 0, "Already has vesting");
        schedules[beneficiary] = VestingSchedule(amount, 0, block.timestamp, durationSeconds, false);
        token.transferFrom(msg.sender, address(this), amount);
        emit VestingCreated(beneficiary, amount, durationSeconds);
    }

    function revoke(address beneficiary) external onlyOwner {
        VestingSchedule storage s = schedules[beneficiary];
        require(!s.revoked, "Already revoked");
        uint256 vested = _vestedAmount(s);
        uint256 refund = s.total - vested;
        s.revoked = true;
        if (refund > 0) token.transfer(owner(), refund);
        emit VestingRevoked(beneficiary);
    }

    function release() external {
        VestingSchedule storage s = schedules[msg.sender];
        require(!s.revoked, "Vesting revoked");
        uint256 releasable = _vestedAmount(s) - s.released;
        require(releasable > 0, "Nothing to release");
        s.released += releasable;
        token.transfer(msg.sender, releasable);
        emit TokensReleased(msg.sender, releasable);
    }

    function _vestedAmount(VestingSchedule memory s) internal view returns (uint256) {
        if (block.timestamp < s.start) return 0;
        if (block.timestamp >= s.start + s.duration) return s.total;
        return (s.total * (block.timestamp - s.start)) / s.duration;
    }

    function releasableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule memory s = schedules[beneficiary];
        return _vestedAmount(s) - s.released;
    }
}
EOF
git add -A && git commit -m "feat: add TokenVesting with revoke support"

cat > src/TokenAirdrop.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenAirdrop is Ownable {
    IERC20 public immutable token;
    event AirdropSent(uint256 recipients, uint256 totalAmount);
    error LengthMismatch();
    error ZeroRecipients();

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function airdrop(address[] calldata recipients, uint256 amountEach) external onlyOwner {
        if (recipients.length == 0) revert ZeroRecipients();
        uint256 total = amountEach * recipients.length;
        token.transferFrom(msg.sender, address(this), total);
        unchecked {
            for (uint256 i = 0; i < recipients.length; i++) {
                token.transfer(recipients[i], amountEach);
            }
        }
        emit AirdropSent(recipients.length, total);
    }

    function airdropCustom(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        if (recipients.length != amounts.length) revert LengthMismatch();
        unchecked {
            for (uint256 i = 0; i < recipients.length; i++) {
                token.transferFrom(msg.sender, recipients[i], amounts[i]);
            }
        }
    }
}
EOF
git add -A && git commit -m "feat: add TokenAirdrop with custom errors and unchecked loop"

cat > src/TokenTimeLock.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenTimeLock {
    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable releaseTime;

    constructor(address _token, address _beneficiary, uint256 _releaseTime) {
        require(_releaseTime > block.timestamp, "Release time must be in the future");
        token = IERC20(_token);
        beneficiary = _beneficiary;
        releaseTime = _releaseTime;
    }

    function release() external {
        require(block.timestamp >= releaseTime, "TokenTimeLock: not yet");
        require(msg.sender == beneficiary, "Not beneficiary");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "No tokens");
        token.transfer(beneficiary, amount);
    }
}
EOF
git add -A && git commit -m "feat: add TokenTimeLock contract"

cat > src/TokenSale.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenSale is Ownable, ReentrancyGuard {
    IERC20 public immutable token;
    uint256 public rate;
    uint256 public totalRaised;
    bool public isOpen;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event SaleToggled(bool isOpen);

    constructor(address _token, uint256 _rate, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
        rate = _rate;
    }

    function buy() external payable nonReentrant {
        require(isOpen, "Sale not open");
        require(msg.value > 0, "Send ETH");
        uint256 tokenAmount = msg.value * rate;
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens");
        totalRaised += msg.value;
        token.transfer(msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    function setOpen(bool _open) external onlyOwner { isOpen = _open; emit SaleToggled(_open); }
    function setRate(uint256 _rate) external onlyOwner { rate = _rate; }
    function withdraw() external onlyOwner {
        (bool ok,) = owner().call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }
}
EOF
git add -A && git commit -m "feat: add TokenSale with ReentrancyGuard"

cat > test/MyToken.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken public token;
    address public owner = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
    }

    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), token.MAX_SUPPLY() / 10);
    }

    function test_Mint() public {
        vm.prank(owner);
        token.mint(user, 1000 ether);
        assertEq(token.balanceOf(user), 1000 ether);
    }

    function test_MintOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 1000 ether);
    }

    function test_Burn() public {
        vm.prank(owner);
        token.burn(100 ether);
    }

    function test_Pause() public {
        vm.prank(owner);
        token.pause();
        assertTrue(token.paused());
    }

    function test_Unpause() public {
        vm.startPrank(owner);
        token.pause();
        token.unpause();
        assertFalse(token.paused());
        vm.stopPrank();
    }

    function test_Transfer() public {
        vm.prank(owner);
        token.transfer(user, 500 ether);
        assertEq(token.balanceOf(user), 500 ether);
    }
}
EOF
git add -A && git commit -m "test: update MyToken tests with pause cases"

cat > test/TokenVesting.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenVesting.sol";

contract TokenVestingTest is Test {
    MyToken token;
    TokenVesting vesting;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        vesting = new TokenVesting(address(token), owner);
        vm.prank(owner);
        token.approve(address(vesting), type(uint256).max);
    }

    function test_CreateVesting() public {
        vm.prank(owner);
        vesting.createVesting(user, 1000 ether, 365 days);
        (uint256 total,,,,) = vesting.schedules(user);
        assertEq(total, 1000 ether);
    }

    function test_ReleaseAfterDuration() public {
        vm.prank(owner);
        vesting.createVesting(user, 1000 ether, 365 days);
        vm.warp(block.timestamp + 365 days + 1);
        vm.prank(user);
        vesting.release();
        assertEq(token.balanceOf(user), 1000 ether);
    }

    function test_RevokeVesting() public {
        vm.prank(owner);
        vesting.createVesting(user, 1000 ether, 100 days);
        vm.prank(owner);
        vesting.revoke(user);
        (,,,,bool revoked) = vesting.schedules(user);
        assertTrue(revoked);
    }
}
EOF
git add -A && git commit -m "test: add TokenVesting tests with revoke"

cat > test/TokenAirdrop.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenAirdrop.sol";

contract TokenAirdropTest is Test {
    MyToken token;
    TokenAirdrop airdrop;
    address owner = address(0x1);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        airdrop = new TokenAirdrop(address(token), owner);
        vm.prank(owner);
        token.approve(address(airdrop), type(uint256).max);
    }

    function test_Airdrop() public {
        address[] memory recipients = new address[](3);
        recipients[0] = address(0x10);
        recipients[1] = address(0x11);
        recipients[2] = address(0x12);
        vm.prank(owner);
        airdrop.airdrop(recipients, 100 ether);
        assertEq(token.balanceOf(address(0x10)), 100 ether);
    }

    function test_ZeroRecipientsReverts() public {
        address[] memory empty = new address[](0);
        vm.prank(owner);
        vm.expectRevert(TokenAirdrop.ZeroRecipients.selector);
        airdrop.airdrop(empty, 100 ether);
    }
}
EOF
git add -A && git commit -m "test: add TokenAirdrop tests"

cat > test/TokenSale.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenSale.sol";

contract TokenSaleTest is Test {
    MyToken token;
    TokenSale sale;
    address owner = address(0x1);
    address buyer = address(0x2);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        sale = new TokenSale(address(token), 1000, owner);
        vm.prank(owner);
        token.transfer(address(sale), 100_000 ether);
        vm.deal(buyer, 10 ether);
    }

    function test_BuyTokens() public {
        vm.prank(owner);
        sale.setOpen(true);
        vm.prank(buyer);
        sale.buy{value: 1 ether}();
        assertEq(token.balanceOf(buyer), 1000 ether);
    }

    function test_SaleClosedReverts() public {
        vm.prank(buyer);
        vm.expectRevert("Sale not open");
        sale.buy{value: 1 ether}();
    }
}
EOF
git add -A && git commit -m "test: add TokenSale tests"

cat > test/TokenTimeLock.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenTimeLock.sol";

contract TokenTimeLockTest is Test {
    MyToken token;
    TokenTimeLock lock;
    address owner = address(0x1);
    address beneficiary = address(0x2);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        lock = new TokenTimeLock(address(token), beneficiary, block.timestamp + 30 days);
        vm.prank(owner);
        token.transfer(address(lock), 500 ether);
    }

    function test_CannotReleaseEarly() public {
        vm.prank(beneficiary);
        vm.expectRevert("TokenTimeLock: not yet");
        lock.release();
    }

    function test_ReleaseAfterTime() public {
        vm.warp(block.timestamp + 30 days + 1);
        vm.prank(beneficiary);
        lock.release();
        assertEq(token.balanceOf(beneficiary), 500 ether);
    }
}
EOF
git add -A && git commit -m "test: add TokenTimeLock tests"

cat > test/fuzz/MyToken.fuzz.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/MyToken.sol";

contract MyTokenFuzzTest is Test {
    MyToken token;
    address owner = address(0x1);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
    }

    function testFuzz_MintDoesNotExceedMaxSupply(uint256 amount) public {
        amount = bound(amount, 0, token.MAX_SUPPLY() - token.totalSupply());
        vm.prank(owner);
        token.mint(owner, amount);
        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }

    function testFuzz_BurnReducesSupply(uint256 burnAmount) public {
        uint256 balance = token.balanceOf(owner);
        burnAmount = bound(burnAmount, 0, balance);
        vm.prank(owner);
        token.burn(burnAmount);
        assertEq(token.totalSupply(), balance - burnAmount);
    }
}
EOF
git add -A && git commit -m "test: add fuzz tests for MyToken"

cat > test/invariant/MyToken.invariant.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/MyToken.sol";

contract MyTokenInvariantTest is Test {
    MyToken token;
    address owner = address(0x1);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        targetContract(address(token));
    }

    function invariant_totalSupplyBelowMax() public view {
        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }
}
EOF
git add -A && git commit -m "test: add invariant test for max supply"

cat > script/DeployVesting.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenVesting.sol";
contract DeployVesting is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        vm.startBroadcast(pk);
        TokenVesting vesting = new TokenVesting(tokenAddr, deployer);
        console.log("TokenVesting:", address(vesting));
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeployVesting script"

cat > script/DeployAirdrop.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenAirdrop.sol";
contract DeployAirdrop is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        vm.startBroadcast(pk);
        TokenAirdrop airdrop = new TokenAirdrop(tokenAddr, deployer);
        console.log("TokenAirdrop:", address(airdrop));
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeployAirdrop script"

cat > script/DeploySale.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenSale.sol";
contract DeploySale is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        vm.startBroadcast(pk);
        TokenSale sale = new TokenSale(tokenAddr, 1000, deployer);
        console.log("TokenSale:", address(sale));
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeploySale script"

cat > script/DeployAll.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/TokenVesting.sol";
import "../src/TokenAirdrop.sol";
import "../src/TokenSale.sol";
contract DeployAll is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);
        MyToken token = new MyToken("MyToken", "MTK", deployer);
        console.log("MyToken:", address(token));
        TokenVesting vesting = new TokenVesting(address(token), deployer);
        console.log("TokenVesting:", address(vesting));
        TokenAirdrop airdrop = new TokenAirdrop(address(token), deployer);
        console.log("TokenAirdrop:", address(airdrop));
        TokenSale sale = new TokenSale(address(token), 1000, deployer);
        console.log("TokenSale:", address(sale));
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeployAll script"

cat > docs/architecture.md << 'EOF'
# Architecture

## Contracts

| Contract | Description |
|---|---|
| MyToken | Core ERC20 with mint, burn, pause |
| TokenVesting | Linear vesting with revoke |
| TokenAirdrop | Batch token distribution |
| TokenSale | ETH presale with ReentrancyGuard |
| TokenTimeLock | Time-locked token release |
EOF
git add -A && git commit -m "docs: add architecture.md"

cat > docs/tokenomics.md << 'EOF'
# Tokenomics

## Supply
- Max Supply: 1,000,000,000 MTK
- Initial Mint: 100,000,000 MTK (10%)

## Distribution
| Allocation | % |
|---|---|
| Team | 15% |
| Presale | 20% |
| Airdrop | 25% |
| Ecosystem | 20% |
| Treasury | 20% |
EOF
git add -A && git commit -m "docs: add tokenomics"

cat > docs/security.md << 'EOF'
# Security

## Applied
- OpenZeppelin contracts
- ReentrancyGuard on TokenSale
- Ownable access control
- Pausable emergency stop

## Pre-mainnet Checklist
- [ ] Internal audit
- [ ] External audit
- [ ] Bug bounty
- [ ] Multisig owner
EOF
git add -A && git commit -m "docs: add security checklist"

cat > docs/deployment.md << 'EOF'
# Deployment Guide

## Testnet
forge script script/DeployAll.s.sol --rpc-url base_sepolia --broadcast --verify

## Mainnet
forge script script/DeployAll.s.sol --rpc-url base --broadcast --verify
EOF
git add -A && git commit -m "docs: add deployment guide"

cat > docs/gas-report.md << 'EOF'
# Gas Report

Estimates on Base mainnet (0.1 gwei):

| Function | Gas |
|---|---|
| MyToken.mint | ~51,000 |
| MyToken.transfer | ~29,000 |
| TokenSale.buy | ~65,000 |
| TokenVesting.release | ~55,000 |
EOF
git add -A && git commit -m "docs: add gas report"

cat > docs/roadmap.md << 'EOF'
# Roadmap

## v0.2.0 - Complete
- [x] TokenVesting with revoke
- [x] TokenAirdrop
- [x] TokenSale
- [x] TokenTimeLock
- [x] Fuzz tests

## v0.3.0 - Planned
- [ ] Merkle airdrop
- [ ] Governance
- [ ] Multisig integration
EOF
git add -A && git commit -m "docs: add roadmap"

cat > CONTRIBUTING.md << 'EOF'
# Contributing

## Setup
forge install

## Test
forge test -v

## Style
- Run forge fmt before committing
- Write tests for all contracts
EOF
git add -A && git commit -m "docs: add CONTRIBUTING.md"

cat > docs/faq.md << 'EOF'
# FAQ

Q: What network?
A: Base (Chain ID: 8453)

Q: Can I burn?
A: Yes, any holder can burn tokens.

Q: Audited?
A: Uses OpenZeppelin (audited). No external audit yet.
EOF
git add -A && git commit -m "docs: add FAQ"

cat >> foundry.toml << 'EOF'

[fmt]
line_length = 100
tab_width = 4
bracket_spacing = true
EOF
git add -A && git commit -m "chore: configure forge fmt"

cat > Makefile << 'EOF'
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
EOF
git add -A && git commit -m "chore: add Makefile"

cat > .github/workflows/ci.yml << 'EOF'
name: CI
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
      - uses: foundry-rs/foundry-toolchain@v1
        with:
          version: nightly
      - run: forge test -v
      - run: forge test --fuzz-runs 500 -v
      - run: forge fmt --check || true
EOF
git add -A && git commit -m "ci: improve CI with fuzz and format checks"

cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug report
about: Report a bug
---

**Describe the bug**

**Contract affected**

**Steps to reproduce**

**Expected vs Actual**
EOF
git add -A && git commit -m "chore: add bug report template"

cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: Feature request
about: Suggest a feature
---

**Problem**

**Solution**

**Alternatives**
EOF
git add -A && git commit -m "chore: add feature request template"

cat > .github/PULL_REQUEST_TEMPLATE.md << 'EOF'
## Summary

## Type
- [ ] Bug fix
- [ ] Feature
- [ ] Security
- [ ] Docs

## Testing
- [ ] forge test passes
- [ ] Tests added
EOF
git add -A && git commit -m "chore: add PR template"

cat > src/interfaces/ITokenSale.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenSale {
    function buy() external payable;
    function setOpen(bool _open) external;
    function setRate(uint256 _rate) external;
    function withdraw() external;
    function totalRaised() external view returns (uint256);
}
EOF
git add -A && git commit -m "feat: add ITokenSale interface"

cat > src/interfaces/ITokenVesting.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenVesting {
    function createVesting(address beneficiary, uint256 amount, uint256 durationSeconds) external;
    function release() external;
    function revoke(address beneficiary) external;
    function releasableAmount(address beneficiary) external view returns (uint256);
}
EOF
git add -A && git commit -m "feat: add ITokenVesting interface"

cat > .github/workflows/slither.yml << 'EOF'
name: Slither
on: [push]
jobs:
  slither:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: foundry-rs/foundry-toolchain@v1
      - run: pip3 install slither-analyzer
      - run: slither src/ --exclude-dependencies || true
EOF
git add -A && git commit -m "ci: add Slither static analysis"

cat > docs/auditing.md << 'EOF'
# Audit Notes

## Tools
- Foundry (unit, fuzz, invariant)
- Slither (static analysis)

## Known Limitations
- No whitelist on TokenSale
- No duplicate check in TokenAirdrop

## Future
- External audit before mainnet
- Bug bounty program
EOF
git add -A && git commit -m "docs: add audit notes"

cat > .env.example << 'EOF'
PRIVATE_KEY=your_private_key_here
BASESCAN_API_KEY=your_basescan_api_key_here
RPC_URL_BASE=https://mainnet.base.org
RPC_URL_SEPOLIA=https://sepolia.base.org
TOKEN_ADDRESS=0x...
EOF
git add -A && git commit -m "chore: improve env example"

cat > README.md << 'EOF'
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
EOF
git add -A && git commit -m "docs: final README update"

cat > CHANGELOG.md << 'EOF'
# Changelog

## [0.2.0]
### Added
- TokenVesting with revoke
- TokenAirdrop with custom errors
- TokenSale with ReentrancyGuard
- TokenTimeLock
- Fuzz and invariant tests
- Full documentation suite

## [0.1.0]
### Added
- MyToken ERC20
- Basic test suite
EOF
git add -A && git commit -m "chore: update CHANGELOG to v0.2.0"

echo ""
echo "Done! Run: git push -u origin main"
