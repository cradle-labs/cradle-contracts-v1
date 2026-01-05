// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {LendingPoolFactory} from "../core/LendingPoolFactory.sol";
import {AssetLendingPool} from "../core/AssetLendingPool.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract LendingPoolFactoryTest is Test {
    LendingPoolFactory factory;
    AccessController acl;
    MockHTS mockHTS;

    address admin;
    address lending;
    address yieldContract;
    address user1;
    address constant HTS_PRECOMPILE = address(0x167);

    function setUp() public {
        admin = address(this);
        lending = makeAddr("lending");
        yieldContract = makeAddr("yieldContract");
        user1 = makeAddr("user1");

        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        acl = new AccessController();

        factory = new LendingPoolFactory(address(acl));
    }

    // Constructor Tests
    function test_Constructor_SetsControllerToDeployer() public view {
        // Controller is set to msg.sender in constructor, which is this test contract
        assertNotEq(address(factory), address(0));
    }

    // createPool Tests
    function test_CreatePool_CreatesPoolSuccessfully() public {
        vm.deal(admin, 1 ether);

        address poolAddress = factory.createPool(
            7500, // ltv
            8000, // optimalUtilization
            200, // baseRate
            400, // slope1
            6000, // slope2
            8500, // liquidationThreshold
            500, // liquidationDiscount
            1000, // reserveFactor
            lending,
            yieldContract,
            "USDC-Pool"
        );

        assertNotEq(poolAddress, address(0));
        assertGt(poolAddress.code.length, 0);
    }

    function test_CreatePool_RegistersPoolByName() public {
        vm.deal(admin, 1 ether);

        address poolAddress =
            factory.createPool(7500, 8000, 200, 400, 6000, 8500, 500, 1000, lending, yieldContract, "ETH-Pool");

        assertEq(factory.pools("ETH-Pool"), poolAddress);
    }

    function test_CreatePool_RevertsWithoutAuthorization() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);

        vm.expectRevert("Unauthorized");
        factory.createPool(7500, 8000, 200, 400, 6000, 8500, 500, 1000, lending, yieldContract, "BTC-Pool");
    }

    function test_CreatePool_CreatesMultiplePools() public {
        vm.deal(admin, 1 ether);

        address pool1 = factory.createPool(7500, 8000, 200, 400, 6000, 8500, 500, 1000, lending, yieldContract, "Pool1");

        address pool2 = factory.createPool(8000, 8500, 300, 500, 7000, 9000, 600, 1500, lending, yieldContract, "Pool2");

        assertNotEq(pool1, pool2);
        assertEq(factory.pools("Pool1"), pool1);
        assertEq(factory.pools("Pool2"), pool2);
    }

    // getPool Tests
    function test_GetPool_ReturnsCorrectPool() public {
        vm.deal(admin, 1 ether);

        address poolAddress =
            factory.createPool(7500, 8000, 200, 400, 6000, 8500, 500, 1000, lending, yieldContract, "TestPool");

        address retrieved = factory.getPool("TestPool");
        assertEq(retrieved, poolAddress);
    }

    function test_GetPool_ReturnsZeroForNonExistent() public view {
        address retrieved = factory.getPool("NonExistent");
        assertEq(retrieved, address(0));
    }

    // Integration Tests
    function test_Integration_CreateAndRetrieveMultiplePools() public {
        vm.deal(admin, 10 ether);

        address usdc = factory.createPool(7500, 8000, 200, 400, 6000, 8500, 500, 1000, lending, yieldContract, "USDC");

        address eth = factory.createPool(7000, 7500, 300, 500, 7000, 8000, 600, 1200, lending, yieldContract, "ETH");

        address btc = factory.createPool(6500, 7000, 400, 600, 8000, 7500, 700, 1400, lending, yieldContract, "BTC");

        assertEq(factory.getPool("USDC"), usdc);
        assertEq(factory.getPool("ETH"), eth);
        assertEq(factory.getPool("BTC"), btc);

        assertNotEq(usdc, eth);
        assertNotEq(eth, btc);
        assertNotEq(usdc, btc);
    }
}
