// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenSale.sol";
contract DeploySale is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        vm.startBroadcast(pk);
        TokenSale sale = new TokenSale(tokenAddr, 1000, deployer);
        console.log("TokenSale:", address(sale));
        vm.stopBroadcast();
    }
}
