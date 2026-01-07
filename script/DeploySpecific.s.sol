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

contract DeploySpecific is Script {
    function run() external {
        string memory contractName = vm.envString("CONTRACT_NAME");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        if (keccak256(bytes(contractName)) == keccak256(bytes("AccessController"))) {
            AccessController acl = new AccessController();
            console.log("AccessController deployed at:", address(acl));
        } 
        else if (keccak256(bytes(contractName)) == keccak256(bytes("CradleOrderBookSettler"))) {
            address acl = vm.envAddress("ACL_ADDRESS");
            address treasury = vm.envAddress("TREASURY_ADDRESS");
            CradleOrderBookSettler settler = new CradleOrderBookSettler(acl, treasury);
            console.log("CradleOrderBookSettler deployed at:", address(settler));
        }
        else if (keccak256(bytes(contractName)) == keccak256(bytes("AssetFactory"))) {
            address acl = vm.envAddress("ACL_ADDRESS");
            AssetFactory factory = new AssetFactory(acl);
            console.log("AssetFactory deployed at:", address(factory));
        }
        else if (keccak256(bytes(contractName)) == keccak256(bytes("NativeAssetIssuerFactory"))) {
            address acl = vm.envAddress("ACL_ADDRESS");
            uint64 allowList = uint64(vm.envUint("ALLOW_LIST"));
            NativeAssetIssuerFactory factory = new NativeAssetIssuerFactory(acl, allowList);
            console.log("NativeAssetIssuerFactory deployed at:", address(factory));
        }
        else if (keccak256(bytes(contractName)) == keccak256(bytes("BridgedAssetIssuerFactory"))) {
            address acl = vm.envAddress("ACL_ADDRESS");
            uint64 allowList = uint64(vm.envUint("ALLOW_LIST"));
            BridgedAssetIssuerFactory factory = new BridgedAssetIssuerFactory(acl, allowList);
            console.log("BridgedAssetIssuerFactory deployed at:", address(factory));
        }
        else if (keccak256(bytes(contractName)) == keccak256(bytes("CradleAccountFactory"))) {
            address acl = vm.envAddress("ACL_ADDRESS");
            uint64 allowList = uint64(vm.envUint("ALLOW_LIST"));
            CradleAccountFactory factory = new CradleAccountFactory(acl, allowList);
            console.log("CradleAccountFactory deployed at:", address(factory));
        }
        else if (keccak256(bytes(contractName)) == keccak256(bytes("CradleListingFactory"))) {
            address acl = vm.envAddress("ACL_ADDRESS");
            CradleListingFactory factory = new CradleListingFactory(acl);
            console.log("CradleListingFactory deployed at:", address(factory));
        }
        else if (keccak256(bytes(contractName)) == keccak256(bytes("LendingPoolFactory"))) {
            address acl = vm.envAddress("ACL_ADDRESS");
            LendingPoolFactory factory = new LendingPoolFactory(acl);
            console.log("LendingPoolFactory deployed at:", address(factory));
        } else {
            revert(string.concat("Unknown contract name: ", contractName));
        }

        vm.stopBroadcast();
    }
}
