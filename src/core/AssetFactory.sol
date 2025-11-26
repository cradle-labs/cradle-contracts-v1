// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";
import {BaseAsset} from "./BaseAsset.sol";
import {AbstractContractAuthority} from "./AbstractContractAuthority.sol";
import {AccessController} from "./AccessController.sol";

contract AssetFactory is AbstractContractAuthority {
    constructor(address aclContract) AbstractContractAuthority(aclContract, uint64(0)) {}

    function createAsset(string memory _name, string memory _symbol)
        external
        payable
        returns (address, address )
    {
        BaseAsset asset = new BaseAsset{value: msg.value}(_name, _symbol, address(acl), uint64(1));

        return (address(asset), asset.token());
    }
}
