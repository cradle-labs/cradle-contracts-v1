// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CradleListingFactory} from "../core/CradleListingFactory.sol";
import {CradleNativeListing} from "../core/CradleNativeListing.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract CradleListingFactoryTest is Test {
    CradleListingFactory factory;
    AccessController acl;
    MockHTS mockHTS;

    address admin;
    address feeCollector;
    address reserve;
    address asset;
    address purchaseAsset;
    address beneficiary;
    address shadowAsset;
    address user1;
    address constant HTS_PRECOMPILE = address(0x167);

    function setUp() public {
        admin = address(this);
        feeCollector = makeAddr("feeCollector");
        reserve = makeAddr("reserve");
        asset = makeAddr("asset");
        purchaseAsset = makeAddr("purchaseAsset");
        beneficiary = makeAddr("beneficiary");
        shadowAsset = makeAddr("shadowAsset");
        user1 = makeAddr("user1");

        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        // AccessController constructor automatically grants level 0 to msg.sender (this contract)
        acl = new AccessController();

        factory = new CradleListingFactory(address(acl));
    }

    // Constructor Tests
    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(factory.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowListToZero() public view {
        assertEq(factory.controlAllowList(), 0);
    }

    // createListing Tests
    function test_CreateListing_CreatesListingSuccessfully() public {
        address listingAddress =
            factory.createListing(feeCollector, reserve, 1000000, asset, purchaseAsset, 100, beneficiary, shadowAsset);

        assertNotEq(listingAddress, address(0));
        assertGt(listingAddress.code.length, 0);
    }

    function test_CreateListing_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");

        factory.createListing(feeCollector, reserve, 1000000, asset, purchaseAsset, 100, beneficiary, shadowAsset);
    }

    function test_CreateListing_CreatesMultipleListings() public {
        address listing1 =
            factory.createListing(feeCollector, reserve, 1000000, asset, purchaseAsset, 100, beneficiary, shadowAsset);

        address listing2 =
            factory.createListing(feeCollector, reserve, 2000000, asset, purchaseAsset, 200, beneficiary, shadowAsset);

        assertNotEq(listing1, listing2);
    }

    function test_CreateListing_WithDifferentParameters() public {
        address listing =
            factory.createListing(feeCollector, reserve, 5000000, asset, purchaseAsset, 500, beneficiary, shadowAsset);

        assertNotEq(listing, address(0));
    }
}
