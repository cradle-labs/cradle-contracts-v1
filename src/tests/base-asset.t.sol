// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BaseAsset} from "../core/BaseAsset.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract BaseAssetTest is Test {
    BaseAsset baseAsset;
    AccessController acl;
    MockHTS mockHTS;

    address admin;
    address user1;
    address user2;
    address constant HTS_PRECOMPILE = address(0x167);

    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy and etch mock HTS
        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        // Deploy AccessController
        acl = new AccessController();

        // Grant access
        acl.grantAccess(1, admin);

        // Deploy BaseAsset
        vm.deal(admin, 1 ether);
        baseAsset = new BaseAsset{value: 0.1 ether}("Base Asset", "BASE", address(acl), 1);
    }

    // Constructor Tests
    function test_Constructor_CreatesTokenSuccessfully() public view {
        assertNotEq(baseAsset.token(), address(0));
    }

    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(baseAsset.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowList() public view {
        assertEq(baseAsset.controlAllowList(), 1);
    }

    // Mint Tests
    function test_Mint_SucceedsWithAuthorization() public {
        baseAsset.mint(1000);
        // Success if no revert
    }

    function test_Mint_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        baseAsset.mint(1000);
    }

    // Burn Tests
    function test_Burn_SucceedsWithAuthorization() public {
        // First mint some tokens
        baseAsset.mint(1000);
        // Then burn a portion
        baseAsset.burn(100);
        // Success if no revert
    }

    function test_Burn_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        baseAsset.burn(100);
    }
}
