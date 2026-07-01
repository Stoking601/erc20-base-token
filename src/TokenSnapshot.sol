// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenSnapshot
/// @notice Record token holder snapshots for airdrop or governance
contract TokenSnapshot is Ownable {
    struct Snapshot {
        uint256 id;
        uint256 timestamp;
        uint256 blockNumber;
        string description;
    }

    uint256 public snapshotCount;
    mapping(uint256 => Snapshot) public snapshots;
    mapping(uint256 => mapping(address => uint256)) public balanceAtSnapshot;

    event SnapshotTaken(uint256 indexed id, uint256 timestamp, string description);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function takeSnapshot(string calldata description) external onlyOwner returns (uint256) {
        uint256 id = ++snapshotCount;
        snapshots[id] = Snapshot(id, block.timestamp, block.number, description);
        emit SnapshotTaken(id, block.timestamp, description);
        return id;
    }

    function recordBalance(uint256 snapshotId, address account, uint256 balance) external onlyOwner {
        balanceAtSnapshot[snapshotId][account] = balance;
    }

    function getBalanceAt(uint256 snapshotId, address account) external view returns (uint256) {
        return balanceAtSnapshot[snapshotId][account];
    }
}
