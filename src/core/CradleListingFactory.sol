// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { CradleNativeListing } from "./CradleNativeListing.sol";
import {AbstractContractAuthority} from "./AbstractContractAuthority.sol";

contract CradleListingFactory is AbstractContractAuthority {

    constructor(address aclContract) AbstractContractAuthority(aclContract, uint64(0)) {

    }

    function createListing(
        address fee_collector_add,
        address reserve,
        uint256 max_supply,
        address asset,
        address purchase_asset,
        uint256 purchase_price,
        address beneficiary,
        address shadow_asset
    ) public onlyAuthorized returns(address) {
        CradleNativeListing listing = new CradleNativeListing(
            address(acl),
            fee_collector_add,
            reserve,
            max_supply,
            asset,
            purchase_asset,
            purchase_price,
            beneficiary,
            shadow_asset
        );

        return (address(listing));
    }
}