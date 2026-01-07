// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/core/NativeAssetIssuer.sol";

contract InteractNativeAssetIssuer is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address issuerAddress = vm.envAddress("ISSUER_ADDRESS");

        // Interaction Params
        string memory name = vm.envString("ASSET_NAME");
        string memory symbol = vm.envString("ASSET_SYMBOL");
        address acl = vm.envAddress("ACL_ADDRESS");
        uint64 allowList = uint64(vm.envUint("ALLOW_LIST"));

        vm.startBroadcast(deployerPrivateKey);

        NativeAssetIssuer issuer = NativeAssetIssuer(issuerAddress);
        
        (address assetManager, address assetToken) = issuer.createAsset(name, symbol, acl, allowList);
        
        console.log("Asset Created:");
        console.log("Manager Address:", assetManager);
        console.log("Token Address:", assetToken);

        vm.stopBroadcast();
    }
}
