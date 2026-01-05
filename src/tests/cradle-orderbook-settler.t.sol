// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CradleOrderBookSettler} from "../core/CradleOrderBookSettler.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract CradleOrderBookSettlerTest is Test {
    CradleOrderBookSettler settler;
    AccessController acl;
    MockHTS mockHTS;

    address admin;
    address treasury;
    address user1;
    address constant HTS_PRECOMPILE = address(0x167);

    event OrderSettled(
        address indexed bidder,
        address indexed asker,
        address bidAsset,
        address askAsset,
        uint256 bidAssetAmount,
        uint256 askAssetAmount
    );

    function setUp() public {
        admin = address(this);
        treasury = makeAddr("treasury");
        user1 = makeAddr("user1");

        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        acl = new AccessController();
        acl.grantAccess(1, admin);

        settler = new CradleOrderBookSettler(address(acl), treasury);
    }

    // Constructor Tests
    function test_Constructor_SetsTreasuryCorrectly() public view {
        assertEq(settler.order_book_treasury(), treasury);
    }

    function test_Constructor_SetsDefaultFee() public view {
        assertEq(settler.fee(), 50);
    }

    function test_Constructor_SetsBasePoint() public view {
        assertEq(settler.BASE_POINT(), 10000);
    }

    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(settler.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowListToOne() public view {
        assertEq(settler.controlAllowList(), 1);
    }

    // splitAmount Tests
    function test_SplitAmount_CalculatesCorrectly() public view {
        (uint256 fee, uint256 traded) = settler.splitAmount(10000);

        assertEq(fee, 50); // 0.5% of 10000
        assertEq(traded, 9950);
    }

    function test_SplitAmount_WithZeroAmount() public view {
        (uint256 fee, uint256 traded) = settler.splitAmount(0);

        assertEq(fee, 0);
        assertEq(traded, 0);
    }

    function test_SplitAmount_WithLargeAmount() public view {
        (uint256 fee, uint256 traded) = settler.splitAmount(1000000);

        assertEq(fee, 5000); // 0.5% of 1000000
        assertEq(traded, 995000);
    }

    function test_SplitAmount_WithCustomFee() public {
        settler.updateFee(100); // 1%

        (uint256 fee, uint256 traded) = settler.splitAmount(10000);

        assertEq(fee, 100); // 1% of 10000
        assertEq(traded, 9900);
    }

    // updateFee Tests
    function test_UpdateFee_UpdatesSuccessfully() public {
        settler.updateFee(200);
        assertEq(settler.fee(), 200);
    }

    function test_UpdateFee_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        settler.updateFee(100);
    }

    function test_UpdateFee_CanSetToZero() public {
        settler.updateFee(0);
        assertEq(settler.fee(), 0);

        (uint256 feeAmount, uint256 traded) = settler.splitAmount(10000);
        assertEq(feeAmount, 0);
        assertEq(traded, 10000);
    }

    function test_UpdateFee_CanSetToMax() public {
        settler.updateFee(10000); // 100%
        assertEq(settler.fee(), 10000);

        (uint256 feeAmount, uint256 traded) = settler.splitAmount(10000);
        assertEq(feeAmount, 10000);
        assertEq(traded, 0);
    }
}
