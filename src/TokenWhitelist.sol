// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenWhitelist
/// @notice Manage whitelisted addresses for token sale
contract TokenWhitelist is Ownable {
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public allocation;
    uint256 public whitelistCount;

    event AddressWhitelisted(address indexed account, uint256 allocation);
    event AddressRemoved(address indexed account);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function addToWhitelist(address account, uint256 alloc) external onlyOwner {
        require(!isWhitelisted[account], "Already whitelisted");
        isWhitelisted[account] = true;
        allocation[account] = alloc;
        whitelistCount++;
        emit AddressWhitelisted(account, alloc);
    }

    function addBatch(address[] calldata accounts, uint256[] calldata allocs) external onlyOwner {
        require(accounts.length == allocs.length, "Length mismatch");
        for (uint256 i = 0; i < accounts.length; i++) {
            if (!isWhitelisted[accounts[i]]) {
                isWhitelisted[accounts[i]] = true;
                allocation[accounts[i]] = allocs[i];
                whitelistCount++;
                emit AddressWhitelisted(accounts[i], allocs[i]);
            }
        }
    }

    function removeFromWhitelist(address account) external onlyOwner {
        require(isWhitelisted[account], "Not whitelisted");
        isWhitelisted[account] = false;
        allocation[account] = 0;
        whitelistCount--;
        emit AddressRemoved(account);
    }
}
