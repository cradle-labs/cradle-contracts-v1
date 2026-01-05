// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractCradleNativeListing} from "./AbstractCradleNativeListing.sol";

contract CradleNativeListing is AbstractCradleNativeListing {
    constructor(
        address aclContract,
        address fee_collector_add,
        address reserve,
        uint256 max_supply,
        address asset,
        address purchase_asset,
        uint256 _purchase_price,
        address beneficiary,
        address shadow_asset // for accounting
    )
        AbstractCradleNativeListing(
            aclContract,
            fee_collector_add,
            reserve,
            max_supply,
            asset,
            purchase_asset,
            _purchase_price,
            beneficiary,
            shadow_asset
        )
    {}
}
