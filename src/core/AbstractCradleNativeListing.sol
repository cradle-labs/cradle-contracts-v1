// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {ICradleAccount} from "./CradleAccount.sol";
import {AbstractContractAuthority} from "./AbstractContractAuthority.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import { NativeAsset } from "./NativeAsset.sol";

/**
AbstractCradleNativeListing
- this contract controls the listing process before the tokens are actually traded on the cradle orderbook.
It allows early users to purchase the listed asset directly from the lister before it get traded on cradle.
 */
abstract contract AbstractCradleNativeListing is AbstractContractAuthority, ReentrancyGuard {

    enum ListingStatus {
        Pending,
        Open,
        Closed,
        Paused,
        Cancelled
    } 

    address fee_collector;
    uint256 fee = 50;
    uint256 public constant BASE_POINT = 10000;
    address public listing_reserve; // the address where incoming funds will go
    address public listing_beneficiary;
    uint256 public listing_max_supply; // max amount of token to be issued for this listing(there can be multiple listings of the same token)
    NativeAsset public listed_asset;
    /**
    for the purpouses of keeping track of who actually participated in this listing
    for all purpouses it's just a shadow of the listed asset itself but for future checks and also for redeeming with the returnAsset. this will make sure we only distribute to valid users who purchased. this helps account for when an asset is listed multiple times
     */
    NativeAsset public accounting_asset; // 
    address public purchase_asset;
    uint256 public total_distributed = 0;
    uint256 public purchase_price;
    uint256 public raised_asset_amount = 0;
    uint256 public raised_asset_balance = 0;
    ListingStatus public status = ListingStatus.Pending;

    event ListingPurchase(
        address indexed user,
        uint256 amount
    );

    event ListingReturn (
        address indexed user,
        uint256 amount
    );

    event Withdrawal (
        address beneficiary,
        uint256 amount
    );


    // listing factory should provide association check logic
    constructor(
        address aclContract,
        address fee_collector_add,
        address reserve,
        uint256 max_supply,
        address asset,
        address _purchase_asset,
        uint256 _purchase_price,
        address beneficiary,
        address shadow_asset // for accounting 
    )
    AbstractContractAuthority(aclContract, uint64(1))
    {
        fee_collector = fee_collector_add;
        listing_reserve = reserve;
        listing_max_supply = max_supply;
        purchase_asset = _purchase_asset;
        listed_asset = NativeAsset(asset);
        accounting_asset = NativeAsset(shadow_asset);
        purchase_price = _purchase_price;
        listing_beneficiary = beneficiary;

    }

    function updateListingStatus(uint8 update) public onlyAuthorized nonReentrant {
        status = ListingStatus(update);
    }

    function purchase(
        address buyer,
        uint256 amount // amount of listed asset to buy
    ) public onlyAuthorized nonReentrant returns (uint256) {

        if(status != ListingStatus.Open){
            revert("LISTING_NOT_OPEN");
        }


        uint256 remaining = listing_max_supply - total_distributed;

        require(remaining > 0, "LISTING_CLOSED");
        require(remaining >= amount, "AMOUNT_TOO_LARGE");

        uint256 amount_to_transfer = amount * purchase_price;
        listed_asset.mint(uint64(amount));
        accounting_asset.mint(uint64(amount));
        // will handle token association of the account as well as granting kyc for the asset separately
        listed_asset.airdropTokens(buyer, uint64(amount));
        accounting_asset.airdropTokens(buyer, uint64(amount));
        ICradleAccount(buyer).transferAsset(listing_reserve, purchase_asset, amount_to_transfer);
        uint256 fee_value = getFee(amount_to_transfer);
        ICradleAccount(buyer).transferAsset(fee_collector, purchase_asset, fee_value);

        total_distributed += amount;
        raised_asset_amount += amount_to_transfer;
        raised_asset_balance += amount_to_transfer;

        emit ListingPurchase(buyer, amount);

        return (amount_to_transfer);
    }


    function returnAsset(
        address owner,
        uint256 amount // amount of listed asset redeem
    ) public onlyAuthorized nonReentrant returns (uint256) {
        if(status != ListingStatus.Open && status != ListingStatus.Cancelled && status != ListingStatus.Paused){
            revert("LISTING_NOT_OPEN");
        }

        uint256 remaining = listing_max_supply - total_distributed;

        require( remaining > 0, "LISTING_CLOSED");

        uint256 amount_to_receive = amount * purchase_price;
        accounting_asset.wipe(uint64(amount), owner); // if this fails it means the user doesnt have the shadow asset so they might not have participated in this listing
        listed_asset.wipe(uint64(amount), owner);

        ICradleAccount(listing_reserve).transferAsset(owner, purchase_asset, amount_to_receive);

        total_distributed -= amount;
        raised_asset_amount -= amount_to_receive;
        raised_asset_balance -= amount_to_receive;

        emit ListingReturn(owner, amount);

        return (amount_to_receive);
    }


    function withdrawToBeneficiary(
        uint256 amount
    ) public onlyAuthorized nonReentrant {
        uint256 remaining_supply = listing_max_supply - total_distributed;
        require(remaining_supply == 0, "LISTING_OPEN");
        require(raised_asset_balance >= amount, "AMOUNT_INVALID");

        ICradleAccount(listing_reserve).transferAsset(listing_beneficiary, purchase_asset, amount);
        raised_asset_balance -= amount;

        emit Withdrawal(listing_beneficiary, amount);
    }

    function getListingStats() external view returns (
        uint256, // total_distributed
        uint256, // remaining
        uint256, // raised_asset_amount
        uint256, // raised_asset_balance
        uint8 // ListingStatus
    ) {

        return (
            total_distributed,
            listing_max_supply - total_distributed,
            raised_asset_amount,
            raised_asset_balance,
            uint8(status)
        );
    }


    function getFee(uint256 amount) internal view returns(uint256) {
        uint256 value = (amount * fee) / BASE_POINT;
        return (value);
    }

}