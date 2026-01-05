// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NativeAsset} from "../core/NativeAsset.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract NativeAssetTest is Test {
    NativeAsset nativeAsset;
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
        acl.grantAccess(3, admin);

        vm.deal(admin, 1 ether);
        nativeAsset = new NativeAsset{value: 0.1 ether}("Native Token", "NAT", address(acl), 3);
    }

    function test_Constructor_CreatesTokenSuccessfully() public view {
        assertNotEq(nativeAsset.token(), address(0));
    }

    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(nativeAsset.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowList() public view {
        assertEq(nativeAsset.controlAllowList(), 3);
    }

    function test_Mint_SucceedsWithAuthorization() public {
        nativeAsset.mint(1000);
    }

    function test_Mint_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        nativeAsset.mint(1000);
    }

    function test_Burn_SucceedsWithAuthorization() public {
        // First mint some tokens
        nativeAsset.mint(1000);
        // Then burn a portion
        nativeAsset.burn(100);
    }

    function test_Burn_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        nativeAsset.burn(100);
    }
}
