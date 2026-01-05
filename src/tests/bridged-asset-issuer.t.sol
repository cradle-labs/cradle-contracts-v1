// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {BridgedAssetIssuer} from "../core/BridgedAssetIssuer.sol";
import {BridgedAsset} from "../core/BridgedAsset.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract BridgedAssetIssuerTest is Test {
    BridgedAssetIssuer issuer;
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
        acl.grantAccess(2, admin);

        issuer = new BridgedAssetIssuer(treasury, address(acl), 2, reserveToken);
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
        assertEq(issuer.controlAllowList(), 2);
    }

    // createAsset Tests
    function test_CreateAsset_CreatesAssetSuccessfully() public {
        vm.deal(admin, 1 ether);

        (address assetAddress, address tokenAddress) =
            issuer.createAsset{value: 0.1 ether}("Bridged Bitcoin", "bBTC", address(acl), 2);

        assertNotEq(assetAddress, address(0));
        assertNotEq(tokenAddress, address(0));

        BridgedAsset asset = BridgedAsset(assetAddress);
        assertEq(asset.token(), tokenAddress);
    }

    function test_CreateAsset_RegistersAssetBySymbol() public {
        vm.deal(admin, 1 ether);

        (address assetAddress,) = issuer.createAsset{value: 0.1 ether}("Bridged Ethereum", "bETH", address(acl), 2);

        assertEq(address(issuer.bridgedAssets("bETH")), assetAddress);
    }

    function test_CreateAsset_RevertsWithoutAuthorization() public {
        vm.deal(user1, 1 ether);
        vm.prank(user1);

        vm.expectRevert("Unauthorized");
        issuer.createAsset{value: 0.1 ether}("Test", "TST", address(acl), 2);
    }

    function test_CreateAsset_CreatesMultipleAssets() public {
        vm.deal(admin, 1 ether);

        (address asset1,) = issuer.createAsset{value: 0.1 ether}("Asset 1", "A1", address(acl), 2);
        (address asset2,) = issuer.createAsset{value: 0.1 ether}("Asset 2", "A2", address(acl), 2);

        assertNotEq(asset1, asset2);
        assertEq(address(issuer.bridgedAssets("A1")), asset1);
        assertEq(address(issuer.bridgedAssets("A2")), asset2);
    }
}
