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
