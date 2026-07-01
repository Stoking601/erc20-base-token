// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DateUtils {
    uint256 constant DAY = 86400;
    uint256 constant WEEK = 7 * DAY;
    uint256 constant MONTH = 30 * DAY;
    uint256 constant YEAR = 365 * DAY;

    function daysFromNow(uint256 numDays) internal view returns (uint256) {
        return block.timestamp + (numDays * DAY);
    }

    function weeksFromNow(uint256 numWeeks) internal view returns (uint256) {
        return block.timestamp + (numWeeks * WEEK);
    }

    function monthsFromNow(uint256 numMonths) internal view returns (uint256) {
        return block.timestamp + (numMonths * MONTH);
    }

    function isPast(uint256 timestamp) internal view returns (bool) {
        return block.timestamp >= timestamp;
    }
}
