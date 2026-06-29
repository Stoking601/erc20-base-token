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
