// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";

/**
 * CradleLendingAssetManager
 * - the CradleLendingAssetManager handles tokens that are used mainly for the purpouse of liquidity pools
 */
contract CradleLendingAssetManager is AbstractCradleAssetManager {
    constructor(string memory _name, string memory _symbol, address aclContract, uint64 accessLevel)
        AbstractCradleAssetManager(_name, _symbol, aclContract, accessLevel)
    {}
}
