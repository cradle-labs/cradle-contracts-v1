// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { CradleNativeListing } from "../core/CradleNativeListing.sol";
import { AccessController } from "../core/AccessController.sol";
import { MockHTS } from "./utils/MockHTS.sol";

contract CradleNativeListingTest is Test {
    CradleNativeListing listing;
    AccessController acl;
    MockHTS mockHTS;
    
    address admin;
    address feeCollector;
    address reserve;
    address asset;
    address purchaseAsset;
    address beneficiary;
    address shadowAsset;
    address constant HTS_PRECOMPILE = address(0x167);

    function setUp() public {
        admin = address(this);
        feeCollector = makeAddr("feeCollector");
        reserve = makeAddr("reserve");
        asset = makeAddr("asset");
        purchaseAsset = makeAddr("purchaseAsset");
        beneficiary = makeAddr("beneficiary");
        shadowAsset = makeAddr("shadowAsset");
        
        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);
        
        acl = new AccessController();
        acl.grantAccess(1, admin);
        
        listing = new CradleNativeListing(
            address(acl),
            feeCollector,
            reserve,
            1000000,
            asset,
            purchaseAsset,
            100,
            beneficiary,
            shadowAsset
        );
    }

    // Constructor Tests
    function test_Constructor_SetsReserveCorrectly() public view {
        assertEq(listing.reserve(), reserve);
    }

    function test_Constructor_SetsBeneficiaryCorrectly() public view {
        assertEq(listing.beneficiary(), beneficiary);
    }

    function test_Constructor_SetsMaxSupplyCorrectly() public view {
        assertEq(listing.max_supply(), 1000000);
    }

    function test_Constructor_SetsListedAssetCorrectly() public view {
        assertEq(listing.listed_asset(), asset);
    }

    function test_Constructor_SetsPurchaseAssetCorrectly() public view {
        assertEq(listing.purchase_asset(), purchaseAsset);
    }

    function test_Constructor_SetsPurchasePriceCorrectly() public view {
        assertEq(listing.purchase_price(), 100);
    }

    function test_Constructor_SetsParticipationAssetCorrectly() public view {
        assertEq(listing.participation_asset(), shadowAsset);
    }

    function test_Constructor_InitializesStatusToPending() public view {
        assertEq(uint8(listing.status()), uint8(0)); // Pending
    }

    function test_Constructor_InitializesTotalDistributedToZero() public view {
        assertEq(listing.total_distributed(), 0);
    }

    function test_Constructor_InitializesRaisedAssetAmountToZero() public view {
        assertEq(listing.raised_asset_amount(), 0);
    }

    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(listing.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowListToOne() public view {
        assertEq(listing.controlAllowList(), 1);
    }

    // updateListingStatus Tests
    function test_UpdateListingStatus_ChangesStatusToOpen() public {
        listing.updateListingStatus(1); // Open
        assertEq(uint8(listing.status()), 1);
    }

    function test_UpdateListingStatus_ChangesStatusToClosed() public {
        listing.updateListingStatus(2); // Closed
        assertEq(uint8(listing.status()), 2);
    }

    function test_UpdateListingStatus_ChangesStatusToPaused() public {
        listing.updateListingStatus(3); // Paused
        assertEq(uint8(listing.status()), 3);
    }

    function test_UpdateListingStatus_ChangesStatusToCancelled() public {
        listing.updateListingStatus(4); // Cancelled
        assertEq(uint8(listing.status()), 4);
    }

    function test_UpdateListingStatus_RevertsWithoutAuthorization() public {
        address user1 = makeAddr("user1");
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        listing.updateListingStatus(1);
    }
}
