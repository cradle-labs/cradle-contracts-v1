// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICradleAccount} from "./CradleAccount.sol";
/**
 * CradleOrderBookSettler
 * - handles settling of offchain orders in an atomic way
 * uses the CradleAccount
 */

contract CradleOrderBookSettler {
    /**
     * the protocol address. The protocol acts as the main controller of this account and can deposit or withdraw assets
     */
    address public constant PROTOCOL = address(0x1);

    modifier onlyProtocol() {
        require(msg.sender == PROTOCOL, "Operation not authorised");
        _;
    }

    constructor() {}

    function settleOrder(
        address _bidder,
        address _asker,
        address bidAsset,
        address askAsset,
        uint256 bidAssetAmount,
        uint256 askAssetAmount
    ) public onlyProtocol {
        ICradleAccount(_bidder).transferAsset(_asker, askAsset, askAssetAmount);
        ICradleAccount(_asker).transferAsset(_bidder, bidAsset, bidAssetAmount);
        // TODO: emit settlement event
    }
}
