// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title TokenFeeCollector
/// @notice Collect and distribute protocol fees
contract TokenFeeCollector is Ownable {
    IERC20 public immutable token;
    uint256 public feeBps = 100; // 1%
    uint256 public totalCollected;

    mapping(address => uint256) public shares;
    address[] public recipients;

    event FeeCollected(address indexed from, uint256 amount);
    event FeeDistributed(uint256 total);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function collectFee(uint256 amount) external returns (uint256 fee) {
        fee = (amount * feeBps) / 10_000;
        if (fee > 0) {
            token.transferFrom(msg.sender, address(this), fee);
            totalCollected += fee;
            emit FeeCollected(msg.sender, fee);
        }
    }

    function setRecipient(address recipient, uint256 share) external onlyOwner {
        if (shares[recipient] == 0) recipients.push(recipient);
        shares[recipient] = share;
    }

    function distribute() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Nothing to distribute");
        uint256 totalShares;
        for (uint256 i = 0; i < recipients.length; i++) {
            totalShares += shares[recipients[i]];
        }
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 amount = (balance * shares[recipients[i]]) / totalShares;
            token.transfer(recipients[i], amount);
        }
        emit FeeDistributed(balance);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Max 10%");
        feeBps = _feeBps;
    }
}
