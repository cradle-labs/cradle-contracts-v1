// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { NativeAssetIssuer } from "../core/NativeAssetIssuer.sol";
import { NativeAsset } from "../core/NativeAsset.sol";
import { AccessController } from "../core/AccessController.sol";
import { MockHTS } from "./utils/MockHTS.sol";

contract NativeAssetIssuerTest is Test {
    NativeAssetIssuer issuer;
    AccessController acl;
    MockHTS mockHTS;
    
    address admin;
    address treasury;
    address reserveToken;
    address user1;
    address constant HTS_PRECOMPILE = address(0x167);

    function setUp() public {
        admin = address(this);
        treasury = makeAddr("treasury");
        reserveToken = makeAddr("reserveToken");
        user1 = makeAddr("user1");
        
        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);
        
        acl = new AccessController();
        acl.grantAccess(3, admin);
        
        issuer = new NativeAssetIssuer(treasury, address(acl), 3, reserveToken);
    }

    // Constructor Tests
    function test_Constructor_SetsTreasuryCorrectly() public view {
        assertEq(issuer.treasury(), treasury);
    }

    function test_Constructor_SetsReserveTokenCorrectly() public view {
        assertEq(issuer.reserveToken(), reserveToken);
    }

    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(issuer.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowList() public view {
        assertEq(issuer.controlAllowList(), 3);
    }

    // createAsset Tests
    function test_CreateAsset_CreatesAssetSuccessfully() public {
        vm.deal(admin, 1 ether);
        
        (address assetAddress, address tokenAddress) = issuer.createAsset{value: 0.1 ether}(
            "Native Gold",
            "nGOLD",
            address(acl),
            3
        );
        
        assertNotEq(assetAddress, address(0));
        assertNotEq(tokenAddress, address(0));
        
        NativeAsset asset = NativeAsset(assetAddress);
        assertEq(asset.token(), tokenAddress);
    }

    function test_CreateAsset_RegistersAssetBySymbol() public {
        vm.deal(admin, 1 ether);
        
        (address assetAddress,) = issuer.createAsset{value: 0.1 ether}(
            "Native Silver",
            "nSLV",
            address(acl),
            3
        );
        
        assertEq(address(issuer.bridgedAssets("nSLV")), assetAddress);
    }

    function test_CreateAsset_RevertsWithoutAuthorization() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);
        
        vm.expectRevert("Unauthorized");
        issuer.createAsset{value: 0.1 ether}("Test", "TST", address(acl), 3);
    }

    function test_CreateAsset_CreatesMultipleAssets() public {
        vm.deal(admin, 1 ether);
        
        (address asset1,) = issuer.createAsset{value: 0.1 ether}("Asset 1", "N1", address(acl), 3);
        (address asset2,) = issuer.createAsset{value: 0.1 ether}("Asset 2", "N2", address(acl), 3);
        
        assertNotEq(asset1, asset2);
        assertEq(address(issuer.bridgedAssets("N1")), asset1);
        assertEq(address(issuer.bridgedAssets("N2")), asset2);
    }
}
