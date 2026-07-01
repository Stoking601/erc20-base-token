// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library MathUtils {
    function percentage(uint256 amount, uint256 bps) internal pure returns (uint256) {
        return (amount * bps) / 10_000;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function clamp(uint256 value, uint256 lower, uint256 upper) internal pure returns (uint256) {
        return min(max(value, lower), upper);
    }
}
