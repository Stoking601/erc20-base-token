// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MyToken
/// @notice ERC20 token deployed on Base
/// @dev Includes burn and mint functionality
contract MyToken is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 1 billion tokens

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) ERC20(name, symbol) Ownable(initialOwner) {
        // Mint 10% of max supply to deployer
        _mint(initialOwner, MAX_SUPPLY / 10);
    }

    /// @notice Mint new tokens (only owner)
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
    }
}
