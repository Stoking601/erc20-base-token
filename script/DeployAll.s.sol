// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../src/MyToken.sol";
import "../src/TokenVesting.sol";
import "../src/TokenAirdrop.sol";
import "../src/TokenSale.sol";
contract DeployAll is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);
        vm.startBroadcast(pk);
        MyToken token = new MyToken("MyToken", "MTK", deployer);
        console.log("MyToken:", address(token));
        TokenVesting vesting = new TokenVesting(address(token), deployer);
        console.log("TokenVesting:", address(vesting));
        TokenAirdrop airdrop = new TokenAirdrop(address(token), deployer);
        console.log("TokenAirdrop:", address(airdrop));
        TokenSale sale = new TokenSale(address(token), 1000, deployer);
        console.log("TokenSale:", address(sale));
        vm.stopBroadcast();
    }
}
