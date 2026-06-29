// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/MyToken.sol";

contract MyTokenFuzzTest is Test {
    MyToken token;
    address owner = address(0x1);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
    }

    function testFuzz_MintDoesNotExceedMaxSupply(uint256 amount) public {
        amount = bound(amount, 0, token.MAX_SUPPLY() - token.totalSupply());
        vm.prank(owner);
        token.mint(owner, amount);
        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }

    function testFuzz_BurnReducesSupply(uint256 burnAmount) public {
        uint256 balance = token.balanceOf(owner);
        burnAmount = bound(burnAmount, 0, balance);
        vm.prank(owner);
        token.burn(burnAmount);
        assertEq(token.totalSupply(), balance - burnAmount);
    }
}
