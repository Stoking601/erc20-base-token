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
