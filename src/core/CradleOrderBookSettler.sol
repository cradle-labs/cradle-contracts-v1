// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICradleAccount} from "./CradleAccount.sol";
import { AbstractContractAuthority } from "./AbstractContractAuthority.sol";
/**
 * CradleOrderBookSettler
 * - handles settling of offchain orders in an atomic way
 * uses the CradleAccount
 */

contract CradleOrderBookSettler is AbstractContractAuthority {

    event OrderSettled(
        address indexed bidder,
        address indexed asker,
        address bidAsset,
        address askAsset,
        uint256 bidAssetAmount,
        uint256 askAssetAmount
    );

    constructor(address aclContract, uint64 allowList) AbstractContractAuthority(aclContract, allowList) {
        bytes memory data = abi.encodeWithSignature("grantAccess(uint64,address)", 6, address(this));

        (bool success, ) = aclContract.delegatecall(data);

        if(!success){
            revert("Failed to grant access to lending pool");
        }
    }

    function settleOrder(
        address _bidder,
        address _asker,
        address bidAsset,
        address askAsset,
        uint256 bidAssetAmount,
        uint256 askAssetAmount
    ) public onlyAuthorized {
        ICradleAccount(_bidder).transferAsset(_asker, askAsset, askAssetAmount);
        ICradleAccount(_asker).transferAsset(_bidder, bidAsset, bidAssetAmount);
        emit OrderSettled(_bidder, _asker, bidAsset, askAsset, bidAssetAmount, askAssetAmount);
    }
}
