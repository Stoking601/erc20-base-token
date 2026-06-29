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
        uint256 expected = token.MAX_SUPPLY() / 10;
        assertEq(token.totalSupply(), expected);
        assertEq(token.balanceOf(owner), expected);
    }

    function test_Mint() public {
        uint256 amount = 1000 * 10 ** 18;
        vm.prank(owner);
        token.mint(user, amount);
        assertEq(token.balanceOf(user), amount);
    }

    function test_MintOnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 1000);
    }

    function test_Burn() public {
        uint256 burnAmount = 100 * 10 ** 18;
        vm.prank(owner);
        token.burn(burnAmount);
        assertEq(token.totalSupply(), token.MAX_SUPPLY() / 10 - burnAmount);
    }

    function test_MaxSupply() public {
        uint256 remaining = token.MAX_SUPPLY() - token.totalSupply();
        vm.prank(owner);
        vm.expectRevert("Exceeds max supply");
        token.mint(user, remaining + 1);
    }

    function test_Transfer() public {
        uint256 amount = 500 * 10 ** 18;
        vm.prank(owner);
        token.transfer(user, amount);
        assertEq(token.balanceOf(user), amount);
    }
}
