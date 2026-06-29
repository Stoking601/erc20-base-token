// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenSale is Ownable, ReentrancyGuard {
    IERC20 public immutable token;
    uint256 public rate;
    uint256 public totalRaised;
    bool public isOpen;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event SaleToggled(bool isOpen);

    constructor(address _token, uint256 _rate, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
        rate = _rate;
    }

    function buy() external payable nonReentrant {
        require(isOpen, "Sale not open");
        require(msg.value > 0, "Send ETH");
        uint256 tokenAmount = msg.value * rate;
        require(token.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens");
        totalRaised += msg.value;
        token.transfer(msg.sender, tokenAmount);
        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    function setOpen(bool _open) external onlyOwner { isOpen = _open; emit SaleToggled(_open); }
    function setRate(uint256 _rate) external onlyOwner { rate = _rate; }
    function withdraw() external onlyOwner {
        (bool ok,) = owner().call{value: address(this).balance}("");
        require(ok, "Withdraw failed");
    }
}
