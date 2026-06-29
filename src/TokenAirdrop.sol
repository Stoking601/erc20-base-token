// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenAirdrop is Ownable {
    IERC20 public immutable token;
    event AirdropSent(uint256 recipients, uint256 totalAmount);
    error LengthMismatch();
    error ZeroRecipients();

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function airdrop(address[] calldata recipients, uint256 amountEach) external onlyOwner {
        if (recipients.length == 0) revert ZeroRecipients();
        uint256 total = amountEach * recipients.length;
        token.transferFrom(msg.sender, address(this), total);
        unchecked {
            for (uint256 i = 0; i < recipients.length; i++) {
                token.transfer(recipients[i], amountEach);
            }
        }
        emit AirdropSent(recipients.length, total);
    }

    function airdropCustom(address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        if (recipients.length != amounts.length) revert LengthMismatch();
        unchecked {
            for (uint256 i = 0; i < recipients.length; i++) {
                token.transferFrom(msg.sender, recipients[i], amounts[i]);
            }
        }
    }
}
