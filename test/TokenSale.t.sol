// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/TokenSale.sol";

contract TokenSaleTest is Test {
    MyToken token;
    TokenSale sale;
    address owner = address(0x1);
    address buyer = address(0x2);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        sale = new TokenSale(address(token), 1000, owner);
        vm.prank(owner);
        token.transfer(address(sale), 100_000 ether);
        vm.deal(buyer, 10 ether);
    }

    function test_BuyTokens() public {
        vm.prank(owner);
        sale.setOpen(true);
        vm.prank(buyer);
        sale.buy{value: 1 ether}();
        assertEq(token.balanceOf(buyer), 1000 ether);
    }

    function test_SaleClosedReverts() public {
        vm.prank(buyer);
        vm.expectRevert("Sale not open");
        sale.buy{value: 1 ether}();
    }
}
