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
