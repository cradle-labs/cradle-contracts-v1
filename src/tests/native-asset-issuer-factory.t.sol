// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {NativeAssetIssuerFactory} from "../core/NativeAssetIssuerFactory.sol";
import {NativeAssetIssuer} from "../core/NativeAssetIssuer.sol";
import {AccessController} from "../core/AccessController.sol";

contract NativeAssetIssuerFactoryTest is Test {
    NativeAssetIssuerFactory public factory;
    AccessController public acl;
    address public treasury;
    address public reserveToken;
    address public authorizedUser;
    address public unauthorizedUser;
    uint64 public allowList;

    event IssuerCreated(address indexed issuer, address indexed treasury, address indexed reserveToken);

    function setUp() public {
        // Set up test addresses
        treasury = makeAddr("treasury");
        reserveToken = makeAddr("reserveToken");
        authorizedUser = makeAddr("authorizedUser");
        unauthorizedUser = makeAddr("unauthorizedUser");
        allowList = 1;

        // Deploy ACL
        acl = new AccessController();

        // Deploy factory
        factory = new NativeAssetIssuerFactory(address(acl), allowList);

        // Set up authorization - grant access to authorizedUser at the allowList level
        acl.grantAccess(allowList, authorizedUser);
    }

    function test_CreateNativeAssetIssuer() public {
        vm.startPrank(authorizedUser);

        vm.expectEmit(false, true, true, true);
        emit IssuerCreated(address(0), treasury, reserveToken);

        address issuerAddress = factory.createNativeAssetIssuer(treasury, address(acl), allowList, reserveToken);

        assertTrue(factory.isIssuer(issuerAddress), "Issuer should be registered");

        NativeAssetIssuer issuer = NativeAssetIssuer(issuerAddress);
        assertEq(issuer.treasury(), treasury, "Treasury should match");
        assertEq(issuer.reserveToken(), reserveToken, "Reserve token should match");

        vm.stopPrank();
    }

    function test_CreateMultipleIssuers() public {
        vm.startPrank(authorizedUser);

        address nativeIssuer1 = factory.createNativeAssetIssuer(treasury, address(acl), allowList, reserveToken);
        address nativeIssuer2 = factory.createNativeAssetIssuer(treasury, address(acl), allowList, reserveToken);

        assertTrue(factory.isIssuer(nativeIssuer1), "First native issuer should be registered");
        assertTrue(factory.isIssuer(nativeIssuer2), "Second native issuer should be registered");

        assertTrue(nativeIssuer1 != nativeIssuer2, "Issuers should have different addresses");

        vm.stopPrank();
    }

    function test_RevertWhen_CreateNativeAssetIssuer_Unauthorized() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert("Unauthorized");
        factory.createNativeAssetIssuer(treasury, address(acl), allowList, reserveToken);
    }
}
