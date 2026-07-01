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
