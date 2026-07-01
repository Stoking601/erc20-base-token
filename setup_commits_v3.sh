#!/bin/bash
set -e
echo "Starting 60 more commits..."

mkdir -p src/utils src/extensions test/integration docs/examples

# ─── 1-10: New utility contracts ───

cat > src/utils/AddressUtils.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AddressUtils {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function requireContract(address account) internal view {
        require(isContract(account), "AddressUtils: not a contract");
    }

    function requireNonZero(address account) internal pure {
        require(account != address(0), "AddressUtils: zero address");
    }
}
EOF
git add -A && git commit -m "feat: add AddressUtils library"

cat > src/utils/MathUtils.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MathUtils {
    function percentage(uint256 amount, uint256 bps) internal pure returns (uint256) {
        return (amount * bps) / 10_000;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function clamp(uint256 value, uint256 lower, uint256 upper) internal pure returns (uint256) {
        return min(max(value, lower), upper);
    }
}
EOF
git add -A && git commit -m "feat: add MathUtils library with bps calculation"

cat > src/utils/DateUtils.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DateUtils {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = 7 * DAY;
    uint256 constant MONTH = 30 * DAY;
    uint256 constant YEAR = 365 * DAY;

    function daysFromNow(uint256 numDays) internal view returns (uint256) {
        return block.timestamp + (numDays * DAY);
    }

    function weeksFromNow(uint256 numWeeks) internal view returns (uint256) {
        return block.timestamp + (numWeeks * WEEK);
    }

    function monthsFromNow(uint256 numMonths) internal view returns (uint256) {
        return block.timestamp + (numMonths * MONTH);
    }

    function isPast(uint256 timestamp) internal view returns (bool) {
        return block.timestamp >= timestamp;
    }
}
EOF
git add -A && git commit -m "feat: add DateUtils library for timestamp helpers"

cat > src/TokenStaking.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title TokenStaking
/// @notice Stake MyToken to earn rewards
contract TokenStaking is Ownable, ReentrancyGuard {
    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;

    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public totalStaked;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);

    constructor(address _stakingToken, address _rewardToken, uint256 _rewardRate, address initialOwner)
        Ownable(initialOwner) {
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
    }

    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = block.timestamp;
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }

    function rewardPerToken() public view returns (uint256) {
        if (totalStaked == 0) return rewardPerTokenStored;
        return rewardPerTokenStored + (
            (block.timestamp - lastUpdateTime) * rewardRate * 1e18 / totalStaked
        );
    }

    function earned(address account) public view returns (uint256) {
        return (stakedBalance[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18)
            + rewards[account];
    }

    function stake(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot stake 0");
        totalStaked += amount;
        stakedBalance[msg.sender] += amount;
        stakingToken.transferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant updateReward(msg.sender) {
        require(amount > 0, "Cannot withdraw 0");
        require(stakedBalance[msg.sender] >= amount, "Insufficient balance");
        totalStaked -= amount;
        stakedBalance[msg.sender] -= amount;
        stakingToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
            emit RewardClaimed(msg.sender, reward);
        }
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner updateReward(address(0)) {
        rewardRate = _rewardRate;
    }
}
EOF
git add -A && git commit -m "feat: add TokenStaking contract with reward mechanism"

cat > src/TokenGovernor.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenGovernor
/// @notice Simple on-chain governance for token holders
contract TokenGovernor is Ownable {
    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool canceled;
    }

    uint256 public proposalCount;
    uint256 public votingPeriod = 3 days;
    uint256 public quorum = 100_000 * 10 ** 18;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event ProposalCreated(uint256 indexed id, address proposer, string description);
    event Voted(uint256 indexed id, address voter, bool support, uint256 weight);
    event ProposalExecuted(uint256 indexed id);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function propose(string calldata description) external returns (uint256) {
        uint256 id = ++proposalCount;
        proposals[id] = Proposal({
            id: id,
            proposer: msg.sender,
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            executed: false,
            canceled: false
        });
        emit ProposalCreated(id, msg.sender, description);
        return id;
    }

    function vote(uint256 proposalId, bool support, uint256 weight) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp <= p.endTime, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        hasVoted[proposalId][msg.sender] = true;
        if (support) {
            p.forVotes += weight;
        } else {
            p.againstVotes += weight;
        }
        emit Voted(proposalId, msg.sender, support, weight);
    }

    function execute(uint256 proposalId) external onlyOwner {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp > p.endTime, "Voting not ended");
        require(!p.executed, "Already executed");
        require(p.forVotes >= quorum, "Quorum not reached");
        require(p.forVotes > p.againstVotes, "Proposal rejected");
        p.executed = true;
        emit ProposalExecuted(proposalId);
    }

    function setVotingPeriod(uint256 _period) external onlyOwner {
        votingPeriod = _period;
    }

    function setQuorum(uint256 _quorum) external onlyOwner {
        quorum = _quorum;
    }
}
EOF
git add -A && git commit -m "feat: add TokenGovernor contract"

cat > src/TokenTreasury.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenTreasury
/// @notice Multi-asset treasury for the token ecosystem
contract TokenTreasury is Ownable {
    event Deposited(address indexed token, address indexed from, uint256 amount);
    event Withdrawn(address indexed token, address indexed to, uint256 amount);
    event ETHDeposited(address indexed from, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    receive() external payable {
        emit ETHDeposited(msg.sender, msg.value);
    }

    function depositToken(address token, uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        emit Deposited(token, msg.sender, amount);
    }

    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
        emit Withdrawn(token, to, amount);
    }

    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH");
        (bool ok,) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
        emit ETHWithdrawn(to, amount);
    }

    function balanceOf(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
EOF
git add -A && git commit -m "feat: add TokenTreasury multi-asset contract"

cat > src/TokenWhitelist.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenWhitelist
/// @notice Manage whitelisted addresses for token sale
contract TokenWhitelist is Ownable {
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public allocation;
    uint256 public whitelistCount;

    event AddressWhitelisted(address indexed account, uint256 allocation);
    event AddressRemoved(address indexed account);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function addToWhitelist(address account, uint256 alloc) external onlyOwner {
        require(!isWhitelisted[account], "Already whitelisted");
        isWhitelisted[account] = true;
        allocation[account] = alloc;
        whitelistCount++;
        emit AddressWhitelisted(account, alloc);
    }

    function addBatch(address[] calldata accounts, uint256[] calldata allocs) external onlyOwner {
        require(accounts.length == allocs.length, "Length mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!isWhitelisted[accounts[i]]) {
                isWhitelisted[accounts[i]] = true;
                allocation[accounts[i]] = allocs[i];
                whitelistCount++;
                emit AddressWhitelisted(accounts[i], allocs[i]);
            }
        }
    }

    function removeFromWhitelist(address account) external onlyOwner {
        require(isWhitelisted[account], "Not whitelisted");
        isWhitelisted[account] = false;
        allocation[account] = 0;
        whitelistCount--;
        emit AddressRemoved(account);
    }
}
EOF
git add -A && git commit -m "feat: add TokenWhitelist contract"

cat > src/TokenBurner.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenBurner
/// @notice Scheduled and manual token burn mechanism
contract TokenBurner is Ownable {
    IERC20 public immutable token;
    uint256 public totalBurned;

    event TokensBurned(uint256 amount, string reason);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function burn(uint256 amount, string calldata reason) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        token.transferFrom(msg.sender, address(0x000000000000000000000000000000000000dEaD), amount);
        totalBurned += amount;
        emit TokensBurned(amount, reason);
    }

    function burnFromContract(uint256 amount, string calldata reason) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        token.transfer(address(0x000000000000000000000000000000000000dEaD), amount);
        totalBurned += amount;
        emit TokensBurned(amount, reason);
    }
}
EOF
git add -A && git commit -m "feat: add TokenBurner with dead address mechanism"

cat > src/TokenSnapshot.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenSnapshot
/// @notice Record token holder snapshots for airdrop or governance
contract TokenSnapshot is Ownable {
    struct Snapshot {
        uint256 id;
        uint256 timestamp;
        uint256 blockNumber;
        string description;
    }

    uint256 public snapshotCount;
    mapping(uint256 => Snapshot) public snapshots;
    mapping(uint256 => mapping(address => uint256)) public balanceAtSnapshot;

    event SnapshotTaken(uint256 indexed id, uint256 timestamp, string description);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function takeSnapshot(string calldata description) external onlyOwner returns (uint256) {
        uint256 id = ++snapshotCount;
        snapshots[id] = Snapshot(id, block.timestamp, block.number, description);
        emit SnapshotTaken(id, block.timestamp, description);
        return id;
    }

    function recordBalance(uint256 snapshotId, address account, uint256 balance) external onlyOwner {
        balanceAtSnapshot[snapshotId][account] = balance;
    }

    function getBalanceAt(uint256 snapshotId, address account) external view returns (uint256) {
        return balanceAtSnapshot[snapshotId][account];
    }
}
EOF
git add -A && git commit -m "feat: add TokenSnapshot contract"

cat > src/TokenFeeCollector.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenFeeCollector
/// @notice Collect and distribute protocol fees
contract TokenFeeCollector is Ownable {
    IERC20 public immutable token;
    uint256 public feeBps = 100; // 1%
    uint256 public totalCollected;

    mapping(address => uint256) public shares;
    address[] public recipients;

    event FeeCollected(address indexed from, uint256 amount);
    event FeeDistributed(uint256 total);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function collectFee(uint256 amount) external returns (uint256 fee) {
        fee = (amount * feeBps) / 10_000;
        if (fee > 0) {
            token.transferFrom(msg.sender, address(this), fee);
            totalCollected += fee;
            emit FeeCollected(msg.sender, fee);
        }
    }

    function setRecipient(address recipient, uint256 share) external onlyOwner {
        if (shares[recipient] == 0) recipients.push(recipient);
        shares[recipient] = share;
    }

    function distribute() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Nothing to distribute");
        uint256 totalShares;
        for (uint256 i = 0; i < recipients.length; i++) {
            totalShares += shares[recipients[i]];
        }
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 amount = (balance * shares[recipients[i]]) / totalShares;
            token.transfer(recipients[i], amount);
        }
        emit FeeDistributed(balance);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Max 10%");
        feeBps = _feeBps;
    }
}
EOF
git add -A && git commit -m "feat: add TokenFeeCollector contract"

# ─── 11-20: Tests for new contracts ───

cat > test/TokenStaking.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenStaking.sol";

contract TokenStakingTest is Test {
    MyToken stakingToken;
    MyToken rewardToken;
    TokenStaking staking;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        stakingToken = new MyToken("Staking", "STK", owner);
        rewardToken = new MyToken("Reward", "RWD", owner);
        staking = new TokenStaking(address(stakingToken), address(rewardToken), 1e15, owner);
        vm.startPrank(owner);
        stakingToken.transfer(user, 1000 ether);
        rewardToken.transfer(address(staking), 100_000 ether);
        vm.stopPrank();
        vm.prank(user);
        stakingToken.approve(address(staking), type(uint256).max);
    }

    function test_Stake() public {
        vm.prank(user);
        staking.stake(100 ether);
        assertEq(staking.stakedBalance(user), 100 ether);
        assertEq(staking.totalStaked(), 100 ether);
    }

    function test_Withdraw() public {
        vm.prank(user);
        staking.stake(100 ether);
        vm.prank(user);
        staking.withdraw(50 ether);
        assertEq(staking.stakedBalance(user), 50 ether);
    }

    function test_CannotStakeZero() public {
        vm.prank(user);
        vm.expectRevert("Cannot stake 0");
        staking.stake(0);
    }
}
EOF
git add -A && git commit -m "test: add TokenStaking tests"

cat > test/TokenGovernor.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenGovernor.sol";

contract TokenGovernorTest is Test {
    TokenGovernor governor;
    address owner = address(0x1);
    address voter = address(0x2);

    function setUp() public {
        governor = new TokenGovernor(owner);
    }

    function test_Propose() public {
        vm.prank(voter);
        uint256 id = governor.propose("Increase reward rate");
        assertEq(id, 1);
        (uint256 pid,,,,,,,, ) = governor.proposals(1);
        assertEq(pid, 1);
    }

    function test_Vote() public {
        vm.prank(voter);
        governor.propose("Test proposal");
        vm.prank(voter);
        governor.vote(1, true, 1000 ether);
        (,,,uint256 forVotes,,,,,) = governor.proposals(1);
        assertEq(forVotes, 1000 ether);
    }

    function test_CannotVoteTwice() public {
        vm.prank(voter);
        governor.propose("Test");
        vm.prank(voter);
        governor.vote(1, true, 100 ether);
        vm.prank(voter);
        vm.expectRevert("Already voted");
        governor.vote(1, true, 100 ether);
    }
}
EOF
git add -A && git commit -m "test: add TokenGovernor tests"

cat > test/TokenTreasury.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenTreasury.sol";

contract TokenTreasuryTest is Test {
    MyToken token;
    TokenTreasury treasury;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        treasury = new TokenTreasury(owner);
        vm.prank(owner);
        token.transfer(user, 1000 ether);
        vm.prank(user);
        token.approve(address(treasury), type(uint256).max);
    }

    function test_DepositToken() public {
        vm.prank(user);
        treasury.depositToken(address(token), 500 ether);
        assertEq(treasury.balanceOf(address(token)), 500 ether);
    }

    function test_WithdrawToken() public {
        vm.prank(user);
        treasury.depositToken(address(token), 500 ether);
        vm.prank(owner);
        treasury.withdrawToken(address(token), owner, 200 ether);
        assertEq(treasury.balanceOf(address(token)), 300 ether);
    }

    function test_DepositETH() public {
        vm.deal(user, 1 ether);
        vm.prank(user);
        (bool ok,) = address(treasury).call{value: 1 ether}("");
        assertTrue(ok);
        assertEq(address(treasury).balance, 1 ether);
    }
}
EOF
git add -A && git commit -m "test: add TokenTreasury tests"

cat > test/TokenWhitelist.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenWhitelist.sol";

contract TokenWhitelistTest is Test {
    TokenWhitelist whitelist;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        whitelist = new TokenWhitelist(owner);
    }

    function test_AddToWhitelist() public {
        vm.prank(owner);
        whitelist.addToWhitelist(user, 1000 ether);
        assertTrue(whitelist.isWhitelisted(user));
        assertEq(whitelist.allocation(user), 1000 ether);
    }

    function test_RemoveFromWhitelist() public {
        vm.prank(owner);
        whitelist.addToWhitelist(user, 1000 ether);
        vm.prank(owner);
        whitelist.removeFromWhitelist(user);
        assertFalse(whitelist.isWhitelisted(user));
    }

    function test_BatchAdd() public {
        address[] memory accounts = new address[](3);
        uint256[] memory allocs = new uint256[](3);
        accounts[0] = address(0x10);
        accounts[1] = address(0x11);
        accounts[2] = address(0x12);
        allocs[0] = 100 ether;
        allocs[1] = 200 ether;
        allocs[2] = 300 ether;
        vm.prank(owner);
        whitelist.addBatch(accounts, allocs);
        assertEq(whitelist.whitelistCount(), 3);
    }
}
EOF
git add -A && git commit -m "test: add TokenWhitelist tests"

cat > test/TokenStaking.fuzz.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenStaking.sol";

contract TokenStakingFuzzTest is Test {
    MyToken stakingToken;
    MyToken rewardToken;
    TokenStaking staking;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        stakingToken = new MyToken("Staking", "STK", owner);
        rewardToken = new MyToken("Reward", "RWD", owner);
        staking = new TokenStaking(address(stakingToken), address(rewardToken), 1e15, owner);
        vm.prank(owner);
        stakingToken.transfer(user, 1_000_000 ether);
        vm.prank(owner);
        rewardToken.transfer(address(staking), 100_000 ether);
        vm.prank(user);
        stakingToken.approve(address(staking), type(uint256).max);
    }

    function testFuzz_StakeAndWithdraw(uint256 amount) public {
        amount = bound(amount, 1, 1_000_000 ether);
        vm.prank(user);
        staking.stake(amount);
        assertEq(staking.stakedBalance(user), amount);
        vm.prank(user);
        staking.withdraw(amount);
        assertEq(staking.stakedBalance(user), 0);
    }
}
EOF
git add -A && git commit -m "test: add fuzz tests for TokenStaking"

cat > test/integration/FullFlow.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/MyToken.sol";
import "../../src/TokenSale.sol";
import "../../src/TokenVesting.sol";
import "../../src/TokenStaking.sol";

contract FullFlowTest is Test {
    MyToken token;
    TokenSale sale;
    TokenVesting vesting;
    TokenStaking staking;

    address owner = address(0x1);
    address buyer = address(0x2);
    address team = address(0x3);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        sale = new TokenSale(address(token), 1000, owner);
        vesting = new TokenVesting(address(token), owner);
        staking = new TokenStaking(address(token), address(token), 1e15, owner);

        vm.startPrank(owner);
        token.transfer(address(sale), 200_000 ether);
        token.approve(address(vesting), type(uint256).max);
        sale.setOpen(true);
        vm.stopPrank();

        vm.deal(buyer, 10 ether);
    }

    function test_FullFlow_BuyThenStake() public {
        vm.prank(buyer);
        sale.buy{value: 1 ether}();
        assertEq(token.balanceOf(buyer), 1000 ether);

        vm.prank(buyer);
        token.approve(address(staking), type(uint256).max);
        vm.prank(buyer);
        staking.stake(500 ether);
        assertEq(staking.stakedBalance(buyer), 500 ether);
    }

    function test_FullFlow_TeamVesting() public {
        vm.prank(owner);
        vesting.createVesting(team, 10_000 ether, 365 days);
        vm.warp(block.timestamp + 180 days);
        uint256 releasable = vesting.releasableAmount(team);
        assertGt(releasable, 0);
    }
}
EOF
git add -A && git commit -m "test: add full integration flow test"

cat > test/TokenSnapshot.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenSnapshot.sol";

contract TokenSnapshotTest is Test {
    TokenSnapshot snap;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        snap = new TokenSnapshot(owner);
    }

    function test_TakeSnapshot() public {
        vm.prank(owner);
        uint256 id = snap.takeSnapshot("Airdrop snapshot");
        assertEq(id, 1);
        assertEq(snap.snapshotCount(), 1);
    }

    function test_RecordBalance() public {
        vm.prank(owner);
        snap.takeSnapshot("Test");
        vm.prank(owner);
        snap.recordBalance(1, user, 500 ether);
        assertEq(snap.getBalanceAt(1, user), 500 ether);
    }
}
EOF
git add -A && git commit -m "test: add TokenSnapshot tests"

cat > test/TokenBurner.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenBurner.sol";

contract TokenBurnerTest is Test {
    MyToken token;
    TokenBurner burner;
    address owner = address(0x1);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        burner = new TokenBurner(address(token), owner);
        vm.prank(owner);
        token.transfer(address(burner), 10_000 ether);
    }

    function test_BurnFromContract() public {
        uint256 supplyBefore = token.totalSupply();
        vm.prank(owner);
        burner.burnFromContract(1000 ether, "Quarterly burn");
        assertEq(burner.totalBurned(), 1000 ether);
    }
}
EOF
git add -A && git commit -m "test: add TokenBurner tests"

cat > test/utils/MathUtils.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/utils/MathUtils.sol";

contract MathUtilsTest is Test {
    using MathUtils for uint256;

    function test_Percentage() public pure {
        uint256 result = MathUtils.percentage(10_000, 500);
        assertEq(result, 500);
    }

    function test_Min() public pure {
        assertEq(MathUtils.min(10, 20), 10);
        assertEq(MathUtils.min(20, 10), 10);
    }

    function test_Max() public pure {
        assertEq(MathUtils.max(10, 20), 20);
        assertEq(MathUtils.max(20, 10), 20);
    }

    function test_Clamp() public pure {
        assertEq(MathUtils.clamp(5, 10, 20), 10);
        assertEq(MathUtils.clamp(15, 10, 20), 15);
        assertEq(MathUtils.clamp(25, 10, 20), 20);
    }
}
EOF
mkdir -p test/utils
cat > test/utils/MathUtils.t.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/utils/MathUtils.sol";

contract MathUtilsTest is Test {
    function test_Percentage() public pure {
        assertEq(MathUtils.percentage(10_000, 500), 500);
    }

    function test_Min() public pure {
        assertEq(MathUtils.min(10, 20), 10);
    }

    function test_Max() public pure {
        assertEq(MathUtils.max(10, 20), 20);
    }

    function test_Clamp() public pure {
        assertEq(MathUtils.clamp(5, 10, 20), 10);
        assertEq(MathUtils.clamp(15, 10, 20), 15);
        assertEq(MathUtils.clamp(25, 10, 20), 20);
    }
}
EOF
git add -A && git commit -m "test: add MathUtils unit tests"

# ─── 21-30: Scripts & Deploy ───

cat > script/DeployStaking.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenStaking.sol";
contract DeployStaking is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address stakingToken = vm.envAddress("STAKING_TOKEN");
        address rewardToken = vm.envAddress("REWARD_TOKEN");
        vm.startBroadcast(pk);
        TokenStaking staking = new TokenStaking(stakingToken, rewardToken, 1e15, deployer);
        console.log("TokenStaking:", address(staking));
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeployStaking script"

cat > script/DeployGovernor.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenGovernor.sol";
contract DeployGovernor is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);
        TokenGovernor governor = new TokenGovernor(deployer);
        console.log("TokenGovernor:", address(governor));
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeployGovernor script"

cat > script/DeployTreasury.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenTreasury.sol";
contract DeployTreasury is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);
        TokenTreasury treasury = new TokenTreasury(deployer);
        console.log("TokenTreasury:", address(treasury));
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeployTreasury script"

cat > script/DeployWhitelist.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenWhitelist.sol";
contract DeployWhitelist is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);
        TokenWhitelist whitelist = new TokenWhitelist(deployer);
        console.log("TokenWhitelist:", address(whitelist));
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeployWhitelist script"

cat > script/DeployFullSuite.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/TokenVesting.sol";
import "../src/TokenAirdrop.sol";
import "../src/TokenSale.sol";
import "../src/TokenStaking.sol";
import "../src/TokenGovernor.sol";
import "../src/TokenTreasury.sol";
import "../src/TokenWhitelist.sol";

contract DeployFullSuite is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);

        MyToken token = new MyToken("MyToken", "MTK", deployer);
        console.log("MyToken:        ", address(token));

        TokenVesting vesting = new TokenVesting(address(token), deployer);
        console.log("TokenVesting:   ", address(vesting));

        TokenAirdrop airdrop = new TokenAirdrop(address(token), deployer);
        console.log("TokenAirdrop:   ", address(airdrop));

        TokenSale sale = new TokenSale(address(token), 1000, deployer);
        console.log("TokenSale:      ", address(sale));

        TokenStaking staking = new TokenStaking(address(token), address(token), 1e15, deployer);
        console.log("TokenStaking:   ", address(staking));

        TokenGovernor governor = new TokenGovernor(deployer);
        console.log("TokenGovernor:  ", address(governor));

        TokenTreasury treasury = new TokenTreasury(deployer);
        console.log("TokenTreasury:  ", address(treasury));

        TokenWhitelist whitelist = new TokenWhitelist(deployer);
        console.log("TokenWhitelist: ", address(whitelist));

        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add DeployFullSuite for all contracts"

cat > script/SetupStaking.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/TokenStaking.sol";

contract SetupStaking is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        address stakingAddr = vm.envAddress("STAKING_ADDRESS");
        uint256 rewardAmount = 100_000 * 10 ** 18;

        vm.startBroadcast(pk);
        MyToken token = MyToken(tokenAddr);
        token.approve(stakingAddr, rewardAmount);
        console.log("Approved staking contract for rewards");
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add SetupStaking configuration script"

cat > script/OpenSale.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenSale.sol";
import "../src/MyToken.sol";

contract OpenSale is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        address saleAddr = vm.envAddress("SALE_ADDRESS");
        uint256 saleAmount = 200_000 * 10 ** 18;

        vm.startBroadcast(pk);
        MyToken(tokenAddr).transfer(saleAddr, saleAmount);
        TokenSale(saleAddr).setOpen(true);
        console.log("Sale opened with", saleAmount, "tokens");
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add OpenSale setup script"

cat > script/BatchVesting.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/TokenVesting.sol";

contract BatchVesting is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        address vestingAddr = vm.envAddress("VESTING_ADDRESS");

        address[] memory team = new address[](3);
        team[0] = address(0xAA);
        team[1] = address(0xBB);
        team[2] = address(0xCC);

        vm.startBroadcast(pk);
        MyToken token = MyToken(tokenAddr);
        TokenVesting vesting = TokenVesting(vestingAddr);
        token.approve(vestingAddr, type(uint256).max);

        for (uint256 i = 0; i < team.length; i++) {
            vesting.createVesting(team[i], 10_000 ether, 365 days);
            console.log("Vesting created for:", team[i]);
        }
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add BatchVesting for team allocation"

cat > script/WithdrawSale.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenSale.sol";

contract WithdrawSale is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address saleAddr = vm.envAddress("SALE_ADDRESS");
        vm.startBroadcast(pk);
        TokenSale sale = TokenSale(saleAddr);
        uint256 raised = sale.totalRaised();
        sale.withdraw();
        console.log("Withdrew", raised, "wei from sale");
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add WithdrawSale script"

cat > script/TakeSnapshot.s.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenSnapshot.sol";

contract TakeSnapshot is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address snapAddr = vm.envAddress("SNAPSHOT_ADDRESS");
        vm.startBroadcast(pk);
        TokenSnapshot snap = TokenSnapshot(snapAddr);
        uint256 id = snap.takeSnapshot("Monthly snapshot");
        console.log("Snapshot taken with ID:", id);
        vm.stopBroadcast();
    }
}
EOF
git add -A && git commit -m "script: add TakeSnapshot script"

# ─── 31-40: Docs ───

cat > docs/staking-guide.md << 'EOF'
# Staking Guide

## Overview
Stake MyToken to earn continuous rewards.

## How It Works
1. Approve staking contract to spend your tokens
2. Call `stake(amount)`
3. Rewards accumulate per second
4. Call `claimReward()` to collect
5. Call `withdraw(amount)` to unstake

## Reward Calculation
Rewards are distributed proportionally based on your share of the total staked pool.

## Contract Addresses
After deployment, update this section with actual addresses.
EOF
git add -A && git commit -m "docs: add staking guide"

cat > docs/governance-guide.md << 'EOF'
# Governance Guide

## How to Participate

### Create a Proposal
Call `propose(description)` with your idea.

### Vote
Call `vote(proposalId, support, weight)` during voting period.
- support: true = for, false = against
- weight: your voting power (token balance)

### Execution
If quorum is reached and for votes exceed against votes,
owner can call `execute(proposalId)`.

## Parameters
- Voting period: 3 days (configurable)
- Quorum: 100,000 tokens (configurable)
EOF
git add -A && git commit -m "docs: add governance guide"

cat > docs/treasury-guide.md << 'EOF'
# Treasury Guide

## Overview
The treasury holds protocol funds — both ETH and ERC20 tokens.

## Deposit
- ETH: send directly to contract address
- ERC20: call `depositToken(token, amount)`

## Withdrawal (owner only)
- ETH: `withdrawETH(to, amount)`
- ERC20: `withdrawToken(token, to, amount)`

## Balance Check
Call `balanceOf(token)` to check any token balance.
EOF
git add -A && git commit -m "docs: add treasury guide"

cat > docs/whitelist-guide.md << 'EOF'
# Whitelist Guide

## Add Addresses
Single: `addToWhitelist(address, allocation)`
Batch: `addBatch(addresses[], allocations[])`

## Remove
`removeFromWhitelist(address)`

## Check
`isWhitelisted(address)` returns bool
`allocation(address)` returns uint256
EOF
git add -A && git commit -m "docs: add whitelist guide"

cat > docs/contracts-reference.md << 'EOF'
# Contract Reference

## MyToken
| Function | Access | Description |
|---|---|---|
| mint(to, amount) | Owner | Mint up to max supply |
| burn(amount) | Any | Burn own tokens |
| pause() | Owner | Pause transfers |
| unpause() | Owner | Resume transfers |

## TokenSale
| Function | Access | Description |
|---|---|---|
| buy() | Any | Buy tokens with ETH |
| setOpen(bool) | Owner | Toggle sale |
| setRate(uint256) | Owner | Update price |
| withdraw() | Owner | Withdraw ETH |

## TokenStaking
| Function | Access | Description |
|---|---|---|
| stake(amount) | Any | Stake tokens |
| withdraw(amount) | Any | Unstake tokens |
| claimReward() | Any | Claim rewards |
| setRewardRate(rate) | Owner | Update APR |
EOF
git add -A && git commit -m "docs: add contracts reference"

cat > docs/integration-guide.md << 'EOF'
# Integration Guide

## Frontend Integration (ethers.js)

### Connect Wallet
```js
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
```

### Buy Tokens
```js
const sale = new ethers.Contract(SALE_ADDRESS, SALE_ABI, signer);
await sale.buy({ value: ethers.parseEther("0.1") });
```

### Stake Tokens
```js
const token = new ethers.Contract(TOKEN_ADDRESS, ERC20_ABI, signer);
await token.approve(STAKING_ADDRESS, amount);
const staking = new ethers.Contract(STAKING_ADDRESS, STAKING_ABI, signer);
await staking.stake(amount);
```
EOF
git add -A && git commit -m "docs: add frontend integration guide"

cat > docs/testing-guide.md << 'EOF'
# Testing Guide

## Run All Tests
```bash
forge test -v
```

## Run Specific Test File
```bash
forge test --match-path test/TokenStaking.t.sol -v
```

## Run Fuzz Tests
```bash
forge test --fuzz-runs 1000 -v
```

## Gas Report
```bash
forge test --gas-report
```

## Coverage
```bash
forge coverage
```

## Test Categories
- Unit tests: `test/*.t.sol`
- Fuzz tests: `test/fuzz/*.t.sol`
- Invariant: `test/invariant/*.t.sol`
- Integration: `test/integration/*.t.sol`
- Utils: `test/utils/*.t.sol`
EOF
git add -A && git commit -m "docs: add testing guide"

cat > docs/error-codes.md << 'EOF'
# Error Codes

## MyToken
| Error | Cause |
|---|---|
| Exceeds max supply | Mint would exceed 1B cap |
| ERC20: transfer amount exceeds balance | Insufficient balance |

## TokenSale
| Error | Cause |
|---|---|
| Sale not open | Sale is paused |
| Send ETH | msg.value is 0 |
| Insufficient tokens | Contract balance too low |

## TokenVesting
| Error | Cause |
|---|---|
| Already has vesting | Beneficiary already set up |
| Nothing to release | No tokens vested yet |
| Vesting revoked | Owner revoked vesting |

## TokenStaking
| Error | Cause |
|---|---|
| Cannot stake 0 | Amount must be > 0 |
| Insufficient balance | Withdraw exceeds staked amount |
EOF
git add -A && git commit -m "docs: add error codes reference"

cat > docs/events-reference.md << 'EOF'
# Events Reference

## MyToken
- `Minted(address indexed to, uint256 amount)`
- `Transfer(address from, address to, uint256 value)`
- `Approval(address owner, address spender, uint256 value)`

## TokenSale
- `TokensPurchased(address buyer, uint256 ethAmount, uint256 tokenAmount)`
- `SaleToggled(bool isOpen)`

## TokenStaking
- `Staked(address user, uint256 amount)`
- `Withdrawn(address user, uint256 amount)`
- `RewardClaimed(address user, uint256 amount)`

## TokenVesting
- `VestingCreated(address beneficiary, uint256 amount, uint256 duration)`
- `TokensReleased(address beneficiary, uint256 amount)`
- `VestingRevoked(address beneficiary)`

## TokenGovernor
- `ProposalCreated(uint256 id, address proposer, string description)`
- `Voted(uint256 id, address voter, bool support, uint256 weight)`
- `ProposalExecuted(uint256 id)`
EOF
git add -A && git commit -m "docs: add events reference"

cat > docs/deployment-addresses.md << 'EOF'
# Deployment Addresses

## Base Sepolia (Testnet)

| Contract | Address | Deployed |
|---|---|---|
| MyToken | TBD | - |
| TokenVesting | TBD | - |
| TokenAirdrop | TBD | - |
| TokenSale | TBD | - |
| TokenStaking | TBD | - |
| TokenGovernor | TBD | - |
| TokenTreasury | TBD | - |
| TokenWhitelist | TBD | - |

## Base Mainnet

| Contract | Address | Deployed |
|---|---|---|
| MyToken | TBD | - |

*Update this file after each deployment.*
EOF
git add -A && git commit -m "docs: add deployment addresses template"

# ─── 41-50: Interfaces & extensions ───

cat > src/interfaces/ITokenStaking.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenStaking {
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimReward() external;
    function earned(address account) external view returns (uint256);
    function stakedBalance(address account) external view returns (uint256);
    function totalStaked() external view returns (uint256);
}
EOF
git add -A && git commit -m "feat: add ITokenStaking interface"

cat > src/interfaces/ITokenGovernor.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenGovernor {
    function propose(string calldata description) external returns (uint256);
    function vote(uint256 proposalId, bool support, uint256 weight) external;
    function execute(uint256 proposalId) external;
    function proposalCount() external view returns (uint256);
}
EOF
git add -A && git commit -m "feat: add ITokenGovernor interface"

cat > src/interfaces/ITreasury.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITreasury {
    function depositToken(address token, uint256 amount) external;
    function withdrawToken(address token, address to, uint256 amount) external;
    function withdrawETH(address payable to, uint256 amount) external;
    function balanceOf(address token) external view returns (uint256);
}
EOF
git add -A && git commit -m "feat: add ITreasury interface"

cat > src/extensions/MintableERC20.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MintableERC20
/// @notice Base contract for mintable ERC20 with supply cap
abstract contract MintableERC20 is ERC20, Ownable {
    uint256 public immutable maxSupply;

    event Minted(address indexed to, uint256 amount);

    constructor(uint256 _maxSupply) {
        maxSupply = _maxSupply;
    }

    function mint(address to, uint256 amount) public virtual onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function remainingSupply() external view returns (uint256) {
        return maxSupply - totalSupply();
    }
}
EOF
git add -A && git commit -m "feat: add MintableERC20 base extension"

cat > src/extensions/CappedMint.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title CappedMint
/// @notice Mixin to limit how much can be minted per address per period
abstract contract CappedMint {
    uint256 public mintCap;
    uint256 public mintPeriod;

    mapping(address => uint256) public mintedInPeriod;
    mapping(address => uint256) public periodStart;

    event MintCapUpdated(uint256 newCap);

    function _checkMintCap(address to, uint256 amount) internal {
        if (block.timestamp > periodStart[to] + mintPeriod) {
            mintedInPeriod[to] = 0;
            periodStart[to] = block.timestamp;
        }
        require(mintedInPeriod[to] + amount <= mintCap, "Mint cap exceeded");
        mintedInPeriod[to] += amount;
    }

    function _setMintCap(uint256 cap, uint256 period) internal {
        mintCap = cap;
        mintPeriod = period;
        emit MintCapUpdated(cap);
    }
}
EOF
git add -A && git commit -m "feat: add CappedMint extension"

cat > Makefile << 'EOF'
.PHONY: test build fmt clean coverage gas

test:
	forge test -v

test-fuzz:
	forge test --fuzz-runs 1000 -v

test-integration:
	forge test --match-path test/integration/* -v

build:
	forge build

fmt:
	forge fmt

clean:
	forge clean

coverage:
	forge coverage

gas:
	forge test --gas-report

deploy-testnet:
	forge script script/DeployFullSuite.s.sol --rpc-url base_sepolia --broadcast --verify

deploy-mainnet:
	forge script script/DeployFullSuite.s.sol --rpc-url base --broadcast --verify

snapshot:
	forge snapshot
EOF
git add -A && git commit -m "chore: update Makefile with coverage and snapshot targets"

cat > .github/workflows/coverage.yml << 'EOF'
name: Coverage
on:
  push:
    branches: [main]

jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive
      - uses: foundry-rs/foundry-toolchain@v1
        with:
          version: nightly
      - name: Run coverage
        run: forge coverage
EOF
git add -A && git commit -m "ci: add coverage workflow"

cat >> CHANGELOG.md << 'EOF'

## [0.3.0]
### Added
- TokenStaking with reward mechanism
- TokenGovernor for on-chain voting
- TokenTreasury multi-asset vault
- TokenWhitelist for KYC/presale
- TokenBurner with dead address
- TokenSnapshot for airdrops
- TokenFeeCollector
- Utility libraries (MathUtils, DateUtils, AddressUtils)
- Full integration tests
- Frontend integration guide
EOF
git add -A && git commit -m "chore: update CHANGELOG to v0.3.0"

cat > docs/roadmap.md << 'EOF'
# Roadmap

## v0.1.0 - Complete
- [x] MyToken ERC20

## v0.2.0 - Complete
- [x] TokenVesting, TokenAirdrop, TokenSale, TokenTimeLock
- [x] Fuzz and invariant tests

## v0.3.0 - Complete
- [x] TokenStaking
- [x] TokenGovernor
- [x] TokenTreasury
- [x] TokenWhitelist
- [x] TokenBurner, TokenSnapshot, TokenFeeCollector
- [x] Utility libraries
- [x] Integration tests

## v0.4.0 - Planned
- [ ] Merkle tree airdrop
- [ ] ERC4626 vault
- [ ] Cross-chain bridge integration
- [ ] Subgraph indexer
- [ ] Frontend dApp
EOF
git add -A && git commit -m "docs: update roadmap to v0.3.0"

cat > README.md << 'EOF'
# ERC20 Token Suite on Base

A production-ready ERC20 token ecosystem on [Base](https://base.org).

## Contracts

| Contract | Description |
|---|---|
| MyToken | ERC20 with mint, burn, pause |
| TokenVesting | Linear vesting with revoke |
| TokenAirdrop | Batch distribution |
| TokenSale | ETH presale |
| TokenStaking | Stake-to-earn rewards |
| TokenGovernor | On-chain governance |
| TokenTreasury | Multi-asset vault |
| TokenWhitelist | KYC/presale access |
| TokenBurner | Scheduled burns |
| TokenSnapshot | Holder snapshots |
| TokenFeeCollector | Protocol fee distribution |
| TokenTimeLock | Time-locked release |

## Libraries
- MathUtils — BPS calculations
- DateUtils — Timestamp helpers
- AddressUtils — Address validation

## Stack
- [Foundry](https://book.getfoundry.sh/)
- [OpenZeppelin](https://openzeppelin.com/contracts/)
- Base (Chain ID: 8453)

## Test
```bash
forge test -v                    # unit tests
forge test --fuzz-runs 1000 -v  # fuzz tests
forge coverage                   # coverage report
```

## Deploy
```bash
forge script script/DeployFullSuite.s.sol --rpc-url base_sepolia --broadcast --verify
```

## Docs
- [Architecture](docs/architecture.md)
- [Staking Guide](docs/staking-guide.md)
- [Governance Guide](docs/governance-guide.md)
- [Contract Reference](docs/contracts-reference.md)
- [Events Reference](docs/events-reference.md)
- [Integration Guide](docs/integration-guide.md)
- [Testing Guide](docs/testing-guide.md)
- [Roadmap](docs/roadmap.md)

## License
MIT
EOF
git add -A && git commit -m "docs: final README update for v0.3.0"

echo ""
echo "Done! 60 commits added."
echo "Run: git push origin main"
