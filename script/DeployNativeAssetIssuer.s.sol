// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/core/NativeAssetIssuer.sol";

contract DeployNativeAssetIssuer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address acl = vm.envAddress("ACL_ADDRESS");
        uint64 allowList = uint64(vm.envUint("ALLOW_LIST"));
        address reserveToken = vm.envAddress("RESERVE_TOKEN_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        NativeAssetIssuer issuer = new NativeAssetIssuer(treasury, acl, allowList, reserveToken);
        console.log("NativeAssetIssuer deployed at:", address(issuer));

        vm.stopBroadcast();
    }
}
