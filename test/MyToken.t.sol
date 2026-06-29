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
