// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";

/**
 * CradleBridgedAssetManager
 * - the CradleBridgedAssetManager controls a cradle bridged asset and handles all aspects of it including minting, burning, wiping and airdropping
 * CradleBridgedAssets are only issued to CradleAccounts marked as bridgers and not to other accounts
 */
contract CradleBridgedAssetManager is AbstractCradleAssetManager {
    constructor(string memory _name, string memory _symbol) payable AbstractCradleAssetManager(_name, _symbol) {}
}
