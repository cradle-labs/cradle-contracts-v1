// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/core/AccessController.sol";
import "../src/core/CradleOrderBookSettler.sol";
import "../src/core/AssetFactory.sol";
import "../src/core/NativeAssetIssuerFactory.sol";
import "../src/core/BridgedAssetIssuerFactory.sol";
import "../src/core/CradleAccountFactory.sol";
import "../src/core/CradleListingFactory.sol";
import "../src/core/LendingPoolFactory.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Default treasury to deployer address if not set
        address treasury = vm.envOr("TREASURY_ADDRESS", vm.addr(deployerPrivateKey));

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy AccessController
        AccessController acl = new AccessController();
        console.log("AccessController deployed at:", address(acl));

        // 2. Deploy CradleOrderBookSettler
        // It requires level 1 access. The deployer (msg.sender) has level 0.
        // Based on AbstractContractAuthority, level 0 implies access to level 1 protected functions.
        CradleOrderBookSettler settler = new CradleOrderBookSettler(address(acl), treasury);
        console.log("CradleOrderBookSettler deployed at:", address(settler));

        acl.grantAccess(0, address(settler));
        console.log("CradleOrderBookSettler added to acl");

        // 3. Deploy AssetFactory
        AssetFactory assetFactory = new AssetFactory(address(acl));
        console.log("AssetFactory deployed at:", address(assetFactory));

        // 4. Deploy AssetIssuerFactories
        // Using allowList = 0 (Super Admin only) for now, can be changed if needed.
        NativeAssetIssuerFactory nativeIssuerFactory = new NativeAssetIssuerFactory(address(acl), 0);
        console.log("NativeAssetIssuerFactory deployed at:", address(nativeIssuerFactory));

        BridgedAssetIssuerFactory bridgedIssuerFactory = new BridgedAssetIssuerFactory(address(acl), 0);
        console.log("BridgedAssetIssuerFactory deployed at:", address(bridgedIssuerFactory));

        // 5. Deploy CradleAccountFactory
        // Using allowList = 0
        CradleAccountFactory accountFactory = new CradleAccountFactory(address(acl), 0);
        console.log("CradleAccountFactory deployed at:", address(accountFactory));

        // 6. Deploy CradleListingFactory
        CradleListingFactory listingFactory = new CradleListingFactory(address(acl));
        console.log("CradleListingFactory deployed at:", address(listingFactory));

        // 7. Deploy LendingPoolFactory
        LendingPoolFactory lendingPoolFactory = new LendingPoolFactory(address(acl));
        console.log("LendingPoolFactory deployed at:", address(lendingPoolFactory));

        vm.stopBroadcast();
    }
}
