// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractAssetsIssuer} from "./AbstractAssetIssuer.sol";
import {BridgedAsset} from "./BridgedAsset.sol";
import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";

contract BridgedAssetIssuer is AbstractAssetsIssuer {
    constructor(address aclContract, uint64 allowList, address reserveToken)
        AbstractAssetsIssuer(aclContract, allowList, reserveToken)
    {}

    function _createAsset(string memory _name, string memory _symbol, address aclContract, uint64 allowList)
        internal
        override
        returns (AbstractCradleAssetManager)
    {
        BridgedAsset asset = new BridgedAsset{value: msg.value}(_name, _symbol, aclContract, allowList);
        return asset;
    }
}
