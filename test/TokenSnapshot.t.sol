// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenSnapshot.sol";

contract TokenSnapshotTest is Test {
    TokenSnapshot snap;
    address owner = address(0x1);
    address user = address(0x2);

    function setUp() public {
        snap = new TokenSnapshot(owner);
    }

    function test_TakeSnapshot() public {
        vm.prank(owner);
        uint256 id = snap.takeSnapshot("Airdrop snapshot");
        assertEq(id, 1);
        assertEq(snap.snapshotCount(), 1);
    }

    function test_RecordBalance() public {
        vm.prank(owner);
        snap.takeSnapshot("Test");
        vm.prank(owner);
        snap.recordBalance(1, user, 500 ether);
        assertEq(snap.getBalanceAt(1, user), 500 ether);
    }
}
