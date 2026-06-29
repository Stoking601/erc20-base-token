// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TokenTimeLock {
    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable releaseTime;

    constructor(address _token, address _beneficiary, uint256 _releaseTime) {
        require(_releaseTime > block.timestamp, "Release time must be in the future");
        token = IERC20(_token);
        beneficiary = _beneficiary;
        releaseTime = _releaseTime;
    }

    function release() external {
        require(block.timestamp >= releaseTime, "TokenTimeLock: not yet");
        require(msg.sender == beneficiary, "Not beneficiary");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "No tokens");
        token.transfer(beneficiary, amount);
    }
}
