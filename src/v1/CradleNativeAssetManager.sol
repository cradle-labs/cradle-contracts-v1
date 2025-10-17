// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";

/**
 * CradleNativeAssetManager
 * - the CradleNativeAssetManager controls all cradle native tokens
 * CradleNativeAssets are only issued and controlled by the protocol
 */
contract CradleNativeAssetManager is AbstractCradleAssetManager {
    constructor(string memory _name, string memory _symbol) payable AbstractCradleAssetManager(_name, _symbol) {}
}
