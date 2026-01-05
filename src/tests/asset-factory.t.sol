// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {AssetFactory} from "../core/AssetFactory.sol";
import {BaseAsset} from "../core/BaseAsset.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract AssetFactoryTest is Test {
    AssetFactory factory;
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

        // Deploy and etch mock HTS at the precompile address
        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        // Deploy AccessController
        acl = new AccessController();

        // Deploy AssetFactory
        factory = new AssetFactory(address(acl));

        // Grant level 1 access to factory for asset creation
        acl.grantAccess(1, address(factory));
    }

    // Constructor Tests
    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(factory.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowListToZero() public view {
        assertEq(factory.controlAllowList(), 0);
    }

    // createAsset Tests
    function test_CreateAsset_CreatesAssetSuccessfully() public {
        string memory name = "Test Asset";
        string memory symbol = "TEST";

        vm.deal(admin, 1 ether);

        (address assetAddress, address tokenAddress) = factory.createAsset{value: 0.1 ether}(name, symbol);

        assertNotEq(assetAddress, address(0), "Asset address should not be zero");
        assertNotEq(tokenAddress, address(0), "Token address should not be zero");

        // Verify the asset contract was created
        assertGt(assetAddress.code.length, 0, "Asset should have code");
    }

    function test_CreateAsset_ReturnsCorrectAddresses() public {
        string memory name = "Test Token";
        string memory symbol = "TT";

        vm.deal(admin, 1 ether);

        (address assetAddress, address tokenAddress) = factory.createAsset{value: 0.1 ether}(name, symbol);

        // Verify the asset's token address matches the returned token address
        BaseAsset asset = BaseAsset(assetAddress);
        assertEq(asset.token(), tokenAddress, "Token addresses should match");
    }

    function test_CreateAsset_CreatesMultipleAssets() public {
        vm.deal(admin, 1 ether);

        (address asset1, address token1) = factory.createAsset{value: 0.1 ether}("Asset 1", "A1");
        (address asset2, address token2) = factory.createAsset{value: 0.1 ether}("Asset 2", "A2");

        assertNotEq(asset1, asset2, "Assets should have different addresses");
        assertNotEq(token1, token2, "Tokens should have different addresses");
    }

    function test_CreateAsset_ForwardsValueToAsset() public {
        uint256 value = 0.5 ether;
        vm.deal(admin, 1 ether);

        uint256 balanceBefore = admin.balance;
        factory.createAsset{value: value}("Test", "TST");
        uint256 balanceAfter = admin.balance;

        assertEq(balanceBefore - balanceAfter, value, "Value should be deducted from sender");
        // Note: Value is consumed by HTS precompile, not retained by the asset contract
    }

    function test_CreateAsset_WorksWithZeroValue() public {
        (address assetAddress, address tokenAddress) = factory.createAsset{value: 0}("Zero Value", "ZV");

        assertNotEq(assetAddress, address(0));
        assertNotEq(tokenAddress, address(0));
        assertEq(assetAddress.balance, 0);
    }

    function test_CreateAsset_SetsCorrectACLInAsset() public {
        vm.deal(admin, 1 ether);

        (address assetAddress,) = factory.createAsset{value: 0.1 ether}("ACL Test", "ACL");

        BaseAsset asset = BaseAsset(assetAddress);
        assertEq(address(asset.acl()), address(acl), "Asset should use same ACL");
    }

    function test_CreateAsset_SetsLevel1AsControlAllowList() public {
        vm.deal(admin, 1 ether);

        (address assetAddress,) = factory.createAsset{value: 0.1 ether}("Level Test", "LVL");

        BaseAsset asset = BaseAsset(assetAddress);
        assertEq(asset.controlAllowList(), 1, "Asset should have level 1 control");
    }

    function test_CreateAsset_WorksWithEmptyStrings() public {
        vm.deal(admin, 1 ether);

        (address assetAddress, address tokenAddress) = factory.createAsset{value: 0.1 ether}("", "");

        assertNotEq(assetAddress, address(0));
        assertNotEq(tokenAddress, address(0));
    }

    function test_CreateAsset_WorksWithLongStrings() public {
        vm.deal(admin, 1 ether);

        string memory longName = "This is a very long asset name that should still work fine";
        string memory longSymbol = "VERYLONGSYMBOL";

        (address assetAddress, address tokenAddress) = factory.createAsset{value: 0.1 ether}(longName, longSymbol);

        assertNotEq(assetAddress, address(0));
        assertNotEq(tokenAddress, address(0));
    }

    function test_CreateAsset_WorksWithSpecialCharacters() public {
        vm.deal(admin, 1 ether);

        (address assetAddress, address tokenAddress) = factory.createAsset{value: 0.1 ether}("Test-Asset_123", "T$T!");

        assertNotEq(assetAddress, address(0));
        assertNotEq(tokenAddress, address(0));
    }

    function test_CreateAsset_CanBeCalledByAnyone() public {
        vm.deal(user1, 1 ether);

        vm.prank(user1);
        (address assetAddress, address tokenAddress) = factory.createAsset{value: 0.1 ether}("User Asset", "UA");

        assertNotEq(assetAddress, address(0));
        assertNotEq(tokenAddress, address(0));
    }

    // Integration Tests
    function test_Integration_CreateAndVerifyAsset() public {
        vm.deal(admin, 1 ether);

        string memory name = "Integration Test";
        string memory symbol = "INT";

        (address assetAddress, address tokenAddress) = factory.createAsset{value: 0.1 ether}(name, symbol);

        BaseAsset asset = BaseAsset(assetAddress);

        // Verify asset properties
        assertEq(address(asset.acl()), address(acl));
        assertEq(asset.token(), tokenAddress);
        assertEq(asset.controlAllowList(), 1);
        // Note: Value is consumed by HTS during token creation
    }

    function test_Integration_CreateMultipleAssetsWithDifferentParams() public {
        vm.deal(admin, 10 ether);

        // Create assets with different parameters
        (address asset1,) = factory.createAsset{value: 0.1 ether}("Asset One", "A1");
        (address asset2,) = factory.createAsset{value: 0.5 ether}("Asset Two", "A2");
        (address asset3,) = factory.createAsset{value: 1 ether}("Asset Three", "A3");

        assertNotEq(asset1, asset2);
        assertNotEq(asset2, asset3);
        assertNotEq(asset1, asset3);

        // Values are consumed by HTS during token creation, not retained in assets
    }

    function test_Integration_CreatedAssetHasCorrectACL() public {
        vm.deal(admin, 1 ether);

        // Grant level 1 access to user1
        acl.grantAccess(1, user1);

        (address assetAddress,) = factory.createAsset{value: 0.1 ether}("Shared Asset", "SHA");

        BaseAsset asset = BaseAsset(assetAddress);

        // Verify that user1 can interact with the asset through ACL
        assertTrue(acl.hasAccess(1, user1));
        assertEq(address(asset.acl()), address(acl));
    }
}
