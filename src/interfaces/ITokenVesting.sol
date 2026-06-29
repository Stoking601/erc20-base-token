// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenVesting {
    function createVesting(address beneficiary, uint256 amount, uint256 durationSeconds) external;
    function release() external;
    function revoke(address beneficiary) external;
    function releasableAmount(address beneficiary) external view returns (uint256);
}
