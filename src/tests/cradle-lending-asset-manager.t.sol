// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CradleLendingAssetManager} from "../core/CradleLendingAssetManager.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract CradleLendingAssetManagerTest is Test {
    CradleLendingAssetManager lendingAsset;
    AccessController acl;
    MockHTS mockHTS;

    address admin;
    address user1;
    address constant HTS_PRECOMPILE = address(0x167);

    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");

        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        acl = new AccessController();
        acl.grantAccess(2, admin);

        vm.deal(admin, 1 ether);
        lendingAsset = new CradleLendingAssetManager{value: 0.1 ether}("Lending Token", "LEND", address(acl), 2);
    }

    function test_Constructor_CreatesTokenSuccessfully() public view {
        assertNotEq(lendingAsset.token(), address(0));
    }

    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(lendingAsset.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowList() public view {
        assertEq(lendingAsset.controlAllowList(), 2);
    }

    function test_Mint_SucceedsWithAuthorization() public {
        lendingAsset.mint(1000);
    }

    function test_Mint_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        lendingAsset.mint(1000);
    }

    function test_Burn_SucceedsWithAuthorization() public {
        // First mint some tokens
        lendingAsset.mint(1000);
        // Then burn a portion
        lendingAsset.burn(100);
    }

    function test_Burn_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        lendingAsset.burn(100);
    }
}
