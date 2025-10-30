// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractAssetsIssuer} from "./AbstractAssetIssuer.sol";
import {NativeAsset} from "./NativeAsset.sol";
import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";

contract NativeAssetIssuer is AbstractAssetsIssuer {
    constructor(address treasury, address aclContract, uint64 allowList, address reserveToken)
        AbstractAssetsIssuer(treasury, aclContract, allowList, reserveToken)
    {}

    function _createAsset(string memory _name, string memory _symbol, address aclContract, uint64 allowList)
        internal
        override
        returns (AbstractCradleAssetManager)
    {
        NativeAsset asset = new NativeAsset{value: msg.value}(_name, _symbol, aclContract, allowList);
        return asset;
    }
}
