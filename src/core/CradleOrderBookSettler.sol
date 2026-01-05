// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICradleAccount} from "./CradleAccount.sol";
import {AbstractContractAuthority} from "./AbstractContractAuthority.sol";
/**
 * CradleOrderBookSettler
 * - handles settling of offchain orders in an atomic way
 * uses the CradleAccount
 */

contract CradleOrderBookSettler is AbstractContractAuthority {
    address public order_book_treasury;
    uint256 public fee = 50;
    uint256 public constant BASE_POINT = 10000;

    event OrderSettled(
        address indexed bidder,
        address indexed asker,
        address bidAsset,
        address askAsset,
        uint256 bidAssetAmount,
        uint256 askAssetAmount
    );

    constructor(address aclContract, address treasury) AbstractContractAuthority(aclContract, uint64(1)) {
        order_book_treasury = treasury;
    }

    function splitAmount(uint256 input_amount) public view returns (uint256, uint256) {
        uint256 as_fee = (input_amount * fee) / BASE_POINT;
        uint256 traded = input_amount - as_fee;
        return (as_fee, traded);
    }

    function updateFee(uint256 new_fee) public onlyAuthorized {
        fee = new_fee;
    }

    function settleOrder(
        address _bidder,
        address _asker,
        address bidAsset,
        address askAsset,
        uint256 bidAssetAmount,
        uint256 askAssetAmount
    ) public onlyAuthorized {
        ICradleAccount(_bidder).unlockAsset(askAsset, askAssetAmount);
        ICradleAccount(_asker).unlockAsset(bidAsset, bidAssetAmount);
        // TODO: will have to add some logic to accounts for anything like users who don't have to pay fees
        (uint256 ask_amount_as_fee, uint256 ask_amount_tradable) = splitAmount(askAssetAmount);
        (uint256 bid_amount_as_fee, uint256 bid_amount_tradable) = splitAmount(bidAssetAmount);
        ICradleAccount(_bidder).transferAsset(_asker, askAsset, ask_amount_tradable);
        ICradleAccount(_bidder).transferAsset(order_book_treasury, askAsset, ask_amount_as_fee);
        ICradleAccount(_asker).transferAsset(_bidder, bidAsset, bid_amount_tradable);
        ICradleAccount(_asker).transferAsset(order_book_treasury, bidAsset, bid_amount_as_fee);

        emit OrderSettled(_bidder, _asker, bidAsset, askAsset, bidAssetAmount, askAssetAmount);
    }
}
