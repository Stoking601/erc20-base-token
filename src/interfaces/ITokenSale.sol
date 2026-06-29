// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITokenSale {
    function buy() external payable;
    function setOpen(bool _open) external;
    function setRate(uint256 _rate) external;
    function withdraw() external;
    function totalRaised() external view returns (uint256);
}
