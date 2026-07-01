// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AddressUtils {
    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

    function requireContract(address account) internal view {
        require(isContract(account), "AddressUtils: not a contract");
    }

    function requireNonZero(address account) internal pure {
        require(account != address(0), "AddressUtils: zero address");
    }
}
