// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyToken.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        MyToken token = new MyToken(
            "MyToken",  // name
            "MTK",      // symbol
            deployer    // initial owner
        );

        console.log("MyToken deployed at:", address(token));
        console.log("Deployer:", deployer);
        console.log("Total supply:", token.totalSupply());

        vm.stopBroadcast();
    }
}
