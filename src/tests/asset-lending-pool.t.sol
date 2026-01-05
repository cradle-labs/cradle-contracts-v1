// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {AssetLendingPool} from "../core/AssetLendingPool.sol";
import {AccessController} from "../core/AccessController.sol";
import {CradleLendingAssetManager} from "../core/CradleLendingAssetManager.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract AssetLendingPoolTest is Test {
    AssetLendingPool pool;
    AccessController acl;
    CradleLendingAssetManager yieldAsset;
    MockHTS mockHTS;

    address admin;
    address lending;
    address user1;
    address constant HTS_PRECOMPILE = address(0x167);

    function setUp() public {
        admin = address(this);
        lending = makeAddr("lending");
        user1 = makeAddr("user1");

        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        acl = new AccessController();
        acl.grantAccess(2, admin);

        // Create yield bearing asset
        vm.deal(admin, 10 ether);
        yieldAsset = new CradleLendingAssetManager{value: 0.1 ether}("Yield Token", "yUSDC", address(acl), 2);

        // Create lending pool
        pool = new AssetLendingPool(
            7500, // ltv (75%)
            8000, // optimalUtilization (80%)
            200, // baseRate (2%)
            400, // slope1 (4%)
            6000, // slope2 (60%)
            8500, // liquidationThreshold (85%)
            500, // liquidationDiscount (5%)
            1000, // reserveFactor (10%)
            lending,
            address(yieldAsset),
            "USDC-Pool",
            address(acl),
            2
        );
    }

    // Constructor Tests
    function test_Constructor_SetsLTVCorrectly() public view {
        assertEq(pool.ltv(), 7500);
    }

    function test_Constructor_SetsOptimalUtilizationCorrectly() public view {
        assertEq(pool.optimalUtilization(), 8000);
    }

    function test_Constructor_SetsBaseRateCorrectly() public view {
        assertEq(pool.baseRate(), 200);
    }

    function test_Constructor_SetsSlope1Correctly() public view {
        assertEq(pool.slope1(), 400);
    }

    function test_Constructor_SetsSlope2Correctly() public view {
        assertEq(pool.slope2(), 6000);
    }

    function test_Constructor_SetsLiquidationThresholdCorrectly() public view {
        assertEq(pool.liquidationThreshold(), 8500);
    }

    function test_Constructor_SetsLiquidationDiscountCorrectly() public view {
        assertEq(pool.liquidationDiscount(), 500);
    }

    function test_Constructor_SetsReserveFactorCorrectly() public view {
        assertEq(pool.reserveFactor(), 1000);
    }

    function test_Constructor_SetsLendingAssetCorrectly() public view {
        assertEq(pool.lendingAsset(), lending);
    }

    function test_Constructor_SetsYieldBearingAssetCorrectly() public view {
        assertEq(address(pool.yieldBearingAsset()), address(yieldAsset));
    }

    function test_Constructor_InitializesBorrowIndexToOneEther() public view {
        assertEq(pool.borrowIndex(), 1e18);
    }

    function test_Constructor_InitializesSupplyIndexToOneEther() public view {
        assertEq(pool.supplyIndex(), 1e18);
    }

    function test_Constructor_InitializesTotalBorrowedToZero() public view {
        assertEq(pool.totalBorrowed(), 0);
    }

    function test_Constructor_InitializesTotalSuppliedToZero() public view {
        assertEq(pool.totalSupplied(), 0);
    }

    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(pool.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowList() public view {
        assertEq(pool.controlAllowList(), 2);
    }

    function test_Constructor_SetsConstantsCorrectly() public view {
        assertEq(pool.BASE_POINT(), 10000);
        assertEq(pool.PRICE_PRECISION(), 1e18);
        assertEq(pool.SECONDS_PER_YEAR(), 365.25 days);
        assertEq(pool.MAX_INDEX(), 1e20);
    }

    // updateOracle Tests
    function test_UpdateOracle_UpdatesMultiplierCorrectly() public {
        address asset = makeAddr("asset");
        pool.updateOracle(asset, 2e18);

        assertEq(pool.assetMultiplierOracle(asset), 2e18);
    }

    function test_UpdateOracle_RevertsWithoutAuthorization() public {
        address asset = makeAddr("asset");
        vm.prank(user1);

        vm.expectRevert("Unauthorized");
        pool.updateOracle(asset, 2e18);
    }

    function test_UpdateOracle_CanUpdateMultipleTimes() public {
        address asset = makeAddr("asset");

        pool.updateOracle(asset, 2e18);
        assertEq(pool.assetMultiplierOracle(asset), 2e18);

        pool.updateOracle(asset, 3e18);
        assertEq(pool.assetMultiplierOracle(asset), 3e18);
    }

    // Integration Tests
    function test_Integration_MultipleOracleUpdates() public {
        address asset1 = makeAddr("asset1");
        address asset2 = makeAddr("asset2");
        address asset3 = makeAddr("asset3");

        pool.updateOracle(asset1, 1e18);
        pool.updateOracle(asset2, 2e18);
        pool.updateOracle(asset3, 5e17);

        assertEq(pool.assetMultiplierOracle(asset1), 1e18);
        assertEq(pool.assetMultiplierOracle(asset2), 2e18);
        assertEq(pool.assetMultiplierOracle(asset3), 5e17);
    }
}
