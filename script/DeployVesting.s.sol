// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenVesting.sol";
contract DeployVesting is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        vm.startBroadcast(pk);
        TokenVesting vesting = new TokenVesting(tokenAddr, deployer);
        console.log("TokenVesting:", address(vesting));
        vm.stopBroadcast();
    }
}
