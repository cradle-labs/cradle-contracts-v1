// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/core/BridgedAssetIssuer.sol";

contract DeployBridgedAssetIssuer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address acl = vm.envAddress("ACL_ADDRESS");
        uint64 allowList = uint64(vm.envUint("ALLOW_LIST"));
        address reserveToken = vm.envAddress("RESERVE_TOKEN_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        BridgedAssetIssuer issuer = new BridgedAssetIssuer(treasury, acl, allowList, reserveToken);
        console.log("BridgedAssetIssuer deployed at:", address(issuer));

        vm.stopBroadcast();
    }
}
