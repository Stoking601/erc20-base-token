// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/TokenAirdrop.sol";
contract DeployAirdrop is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        vm.startBroadcast(pk);
        TokenAirdrop airdrop = new TokenAirdrop(tokenAddr, deployer);
        console.log("TokenAirdrop:", address(airdrop));
        vm.stopBroadcast();
    }
}
