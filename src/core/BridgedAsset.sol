// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { AbstractCradleAssetManager } from "./AbstractCradleAssetManager.sol";


contract BridgedAsset is AbstractCradleAssetManager {
    constructor(string memory _name, string memory _symbol, address aclContract, uint64 allowList ) AbstractCradleAssetManager( _name, _symbol, aclContract, allowList) { 
    }
}