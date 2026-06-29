// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/MyToken.sol";

contract MyTokenInvariantTest is Test {
    MyToken token;
    address owner = address(0x1);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        targetContract(address(token));
    }

    function invariant_totalSupplyBelowMax() public view {
        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }
}
