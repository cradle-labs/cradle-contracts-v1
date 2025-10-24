// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { AbstractCradleAssetManager } from "./AbstractCradleAssetManager.sol";
import { BaseAsset } from "./BaseAsset.sol";

contract AssetFactory {
    

    constructor(){}


    function createAsset(string memory _name, string memory _symbol, address aclContract, uint64 allowList) payable external returns (address) {

        BaseAsset asset = new BaseAsset{value: msg.value}(_name, _symbol, aclContract, allowList);

        return address(asset);
    }
}