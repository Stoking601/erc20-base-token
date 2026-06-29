// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
    IERC20 public immutable token;

    struct VestingSchedule {
        uint256 total;
        uint256 released;
        uint256 start;
        uint256 duration;
        bool revoked;
    }

    mapping(address => VestingSchedule) public schedules;

    event VestingCreated(address indexed beneficiary, uint256 amount, uint256 duration);
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);

    constructor(address _token, address initialOwner) Ownable(initialOwner) {
        token = IERC20(_token);
    }

    function createVesting(address beneficiary, uint256 amount, uint256 durationSeconds) external onlyOwner {
        require(schedules[beneficiary].total == 0, "Already has vesting");
        schedules[beneficiary] = VestingSchedule(amount, 0, block.timestamp, durationSeconds, false);
        token.transferFrom(msg.sender, address(this), amount);
        emit VestingCreated(beneficiary, amount, durationSeconds);
    }

    function revoke(address beneficiary) external onlyOwner {
        VestingSchedule storage s = schedules[beneficiary];
        require(!s.revoked, "Already revoked");
        uint256 vested = _vestedAmount(s);
        uint256 refund = s.total - vested;
        s.revoked = true;
        if (refund > 0) token.transfer(owner(), refund);
        emit VestingRevoked(beneficiary);
    }

    function release() external {
        VestingSchedule storage s = schedules[msg.sender];
        require(!s.revoked, "Vesting revoked");
        uint256 releasable = _vestedAmount(s) - s.released;
        require(releasable > 0, "Nothing to release");
        s.released += releasable;
        token.transfer(msg.sender, releasable);
        emit TokensReleased(msg.sender, releasable);
    }

    function _vestedAmount(VestingSchedule memory s) internal view returns (uint256) {
        if (block.timestamp < s.start) return 0;
        if (block.timestamp >= s.start + s.duration) return s.total;
        return (s.total * (block.timestamp - s.start)) / s.duration;
    }

    function releasableAmount(address beneficiary) external view returns (uint256) {
        VestingSchedule memory s = schedules[beneficiary];
        return _vestedAmount(s) - s.released;
    }
}
