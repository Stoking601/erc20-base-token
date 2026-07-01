// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenBurner
/// @notice Scheduled and manual token burn mechanism
contract TokenBurner is Ownable {
    IERC20 public immutable token;
    uint256 public totalBurned;

    event TokensBurned(uint256 amount, string reason);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function burn(uint256 amount, string calldata reason) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        token.transferFrom(msg.sender, address(0x000000000000000000000000000000000000dEaD), amount);
        totalBurned += amount;
        emit TokensBurned(amount, reason);
    }

    function burnFromContract(uint256 amount, string calldata reason) external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        token.transfer(address(0x000000000000000000000000000000000000dEaD), amount);
        totalBurned += amount;
        emit TokensBurned(amount, reason);
    }
}
