// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {ICradleAccount} from "./CradleAccount.sol";
import {AbstractContractAuthority} from "./AbstractContractAuthority.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import { NativeAsset } from "./NativeAsset.sol";
import { IERC20Metadata } from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
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
    address public reserve; // the address where incoming funds will go
    address public beneficiary;
    uint256 public max_supply; // max amount of token to be issued for this listing(there can be multiple listings of the same token)
    address public listed_asset; // asset this listing is issuing 
    /**
    for the purpouses of keeping track of who actually participated in this listing
    for all purpouses it's just a shadow of the listed asset itself but for future checks and also for redeeming with the returnAsset. this will make sure we only distribute to valid users who purchased. this helps account for when an asset is listed multiple times
     */
    address public participation_asset; // the shadow asset meant to be tied to this specific trade(marks that a user got the amount of tokens they have in their account specifically through this listing)
    address public purchase_asset; // asset that the listed asset will be bought with 
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
        address _reserve,
        uint256 _max_supply,
        address _listed_asset,
        address _purchase_asset,
        uint256 _purchase_price,
        address _beneficiary,
        address _participation_asset // for accounting 
    )
    AbstractContractAuthority(aclContract, uint64(1))
    {
        fee_collector = fee_collector_add;
        reserve = _reserve;
        max_supply = _max_supply;
        purchase_asset = _purchase_asset;
        listed_asset = _listed_asset;
        participation_asset = _participation_asset;
        purchase_price = _purchase_price;
        beneficiary = _beneficiary;

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


        uint256 remaining = max_supply - total_distributed;

        require(remaining > 0, "LISTING_CLOSED");
        require(remaining >= amount, "AMOUNT_TOO_LARGE");

        uint256 amount_to_transfer = (amount * purchase_price) / (10 ** IERC20Metadata(listed_asset).decimals());
        
        ICradleAccount(reserve).transferAsset(buyer, listed_asset, amount);
        ICradleAccount(reserve).transferAsset(buyer, participation_asset, amount);
        ICradleAccount(buyer).transferAsset(reserve, purchase_asset, amount_to_transfer);
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

        uint256 remaining = max_supply - total_distributed;

        require( remaining > 0, "LISTING_CLOSED");

        uint256 amount_to_receive = (amount * purchase_price) / (10 ** IERC20Metadata(purchase_asset).decimals());

        ICradleAccount(owner).transferAsset(reserve, listed_asset, amount);
        ICradleAccount(owner).transferAsset(reserve, participation_asset, amount);
        ICradleAccount(reserve).transferAsset(owner, purchase_asset, amount_to_receive);

        total_distributed -= amount;
        raised_asset_amount -= amount_to_receive;
        raised_asset_balance -= amount_to_receive;

        emit ListingReturn(owner, amount);

        return (amount_to_receive);
    }


    function withdrawToBeneficiary(
        uint256 amount
    ) public onlyAuthorized nonReentrant {
        uint256 remaining_supply = max_supply - total_distributed;
        require(remaining_supply == 0, "LISTING_OPEN");
        require(raised_asset_balance >= amount, "AMOUNT_INVALID");

        ICradleAccount(reserve).transferAsset(beneficiary, purchase_asset, amount);
        raised_asset_balance -= amount;

        emit Withdrawal(beneficiary, amount);
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
            max_supply - total_distributed,
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