// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenBurner.sol";

contract TokenBurnerTest is Test {
    MyToken token;
    TokenBurner burner;
    address owner = address(0x1);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        burner = new TokenBurner(address(token), owner);
        vm.prank(owner);
        token.transfer(address(burner), 10_000 ether);
    }

    function test_BurnFromContract() public {
        uint256 supplyBefore = token.totalSupply();
        vm.prank(owner);
        burner.burnFromContract(1000 ether, "Quarterly burn");
        assertEq(burner.totalBurned(), 1000 ether);
    }
}
