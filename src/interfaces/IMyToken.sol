// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMyToken {
    function mint(address to, uint256 amount) external;
    function pause() external;
    function unpause() external;
    function MAX_SUPPLY() external view returns (uint256);
}
