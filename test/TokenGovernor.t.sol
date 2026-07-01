// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TokenGovernor.sol";

contract TokenGovernorTest is Test {
    TokenGovernor governor;
    address owner = address(0x1);
    address voter = address(0x2);

    function setUp() public {
        governor = new TokenGovernor(owner);
    }

    function test_Propose() public {
        vm.prank(voter);
        uint256 id = governor.propose("Increase reward rate");
        assertEq(id, 1);
        (uint256 pid,,,,,,,, ) = governor.proposals(1);
        assertEq(pid, 1);
    }

    function test_Vote() public {
        vm.prank(voter);
        governor.propose("Test proposal");
        vm.prank(voter);
        governor.vote(1, true, 1000 ether);
        (,,,uint256 forVotes,,,,,) = governor.proposals(1);
        assertEq(forVotes, 1000 ether);
    }

    function test_CannotVoteTwice() public {
        vm.prank(voter);
        governor.propose("Test");
        vm.prank(voter);
        governor.vote(1, true, 100 ether);
        vm.prank(voter);
        vm.expectRevert("Already voted");
        governor.vote(1, true, 100 ether);
    }
}
