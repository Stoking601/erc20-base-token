// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/MyToken.sol";
import "../../src/TokenSale.sol";
import "../../src/TokenVesting.sol";
import "../../src/TokenStaking.sol";

contract FullFlowTest is Test {
    MyToken token;
    TokenSale sale;
    TokenVesting vesting;
    TokenStaking staking;

    address owner = address(0x1);
    address buyer = address(0x2);
    address team = address(0x3);

    function setUp() public {
        token = new MyToken("MyToken", "MTK", owner);
        sale = new TokenSale(address(token), 1000, owner);
        vesting = new TokenVesting(address(token), owner);
        staking = new TokenStaking(address(token), address(token), 1e15, owner);

        vm.startPrank(owner);
        token.transfer(address(sale), 200_000 ether);
        token.approve(address(vesting), type(uint256).max);
        sale.setOpen(true);
        vm.stopPrank();

        vm.deal(buyer, 10 ether);
    }

    function test_FullFlow_BuyThenStake() public {
        vm.prank(buyer);
        sale.buy{value: 1 ether}();
        assertEq(token.balanceOf(buyer), 1000 ether);

        vm.prank(buyer);
        token.approve(address(staking), type(uint256).max);
        vm.prank(buyer);
        staking.stake(500 ether);
        assertEq(staking.stakedBalance(buyer), 500 ether);
    }

    function test_FullFlow_TeamVesting() public {
        vm.prank(owner);
        vesting.createVesting(team, 10_000 ether, 365 days);
        vm.warp(block.timestamp + 180 days);
        uint256 releasable = vesting.releasableAmount(team);
        assertGt(releasable, 0);
    }
}
