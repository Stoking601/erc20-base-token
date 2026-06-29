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
