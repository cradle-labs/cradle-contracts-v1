// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { BridgedAsset } from "../core/BridgedAsset.sol";
import { AccessController } from "../core/AccessController.sol";
import { MockHTS } from "./utils/MockHTS.sol";

contract BridgedAssetTest is Test {
    BridgedAsset bridgedAsset;
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
        bridgedAsset = new BridgedAsset{value: 0.1 ether}("Bridged USDC", "bUSDC", address(acl), 2);
    }

    function test_Constructor_CreatesTokenSuccessfully() public view {
        assertNotEq(bridgedAsset.token(), address(0));
    }

    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(bridgedAsset.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowList() public view {
        assertEq(bridgedAsset.controlAllowList(), 2);
    }

    function test_Mint_SucceedsWithAuthorization() public {
        bridgedAsset.mint(1000);
    }

    function test_Mint_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        bridgedAsset.mint(1000);
    }

    function test_Burn_SucceedsWithAuthorization() public {
        // First mint some tokens
        bridgedAsset.mint(1000);
        // Then burn a portion
        bridgedAsset.burn(100);
    }

    function test_Burn_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        bridgedAsset.burn(100);
    }
}
