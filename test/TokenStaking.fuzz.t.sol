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
