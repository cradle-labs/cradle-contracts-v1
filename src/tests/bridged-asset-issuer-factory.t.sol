// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {BridgedAssetIssuerFactory} from "../core/BridgedAssetIssuerFactory.sol";
import {BridgedAssetIssuer} from "../core/BridgedAssetIssuer.sol";
import {AccessController} from "../core/AccessController.sol";

contract BridgedAssetIssuerFactoryTest is Test {
    BridgedAssetIssuerFactory public factory;
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
        factory = new BridgedAssetIssuerFactory(address(acl), allowList);

        // Set up authorization - grant access to authorizedUser at the allowList level
        acl.grantAccess(allowList, authorizedUser);
    }

    function test_CreateBridgedAssetIssuer() public {
        vm.startPrank(authorizedUser);

        vm.expectEmit(false, true, true, true);
        emit IssuerCreated(address(0), treasury, reserveToken);

        address issuerAddress = factory.createBridgedAssetIssuer(treasury, address(acl), allowList, reserveToken);

        assertTrue(factory.isIssuer(issuerAddress), "Issuer should be registered");

        BridgedAssetIssuer issuer = BridgedAssetIssuer(issuerAddress);
        assertEq(issuer.treasury(), treasury, "Treasury should match");
        assertEq(issuer.reserveToken(), reserveToken, "Reserve token should match");

        vm.stopPrank();
    }

    function test_CreateMultipleIssuers() public {
        vm.startPrank(authorizedUser);

        address bridgedIssuer1 = factory.createBridgedAssetIssuer(treasury, address(acl), allowList, reserveToken);
        address bridgedIssuer2 = factory.createBridgedAssetIssuer(treasury, address(acl), allowList, reserveToken);

        assertTrue(factory.isIssuer(bridgedIssuer1), "First bridged issuer should be registered");
        assertTrue(factory.isIssuer(bridgedIssuer2), "Second bridged issuer should be registered");

        assertTrue(bridgedIssuer1 != bridgedIssuer2, "Issuers should have different addresses");

        vm.stopPrank();
    }

    function test_RevertWhen_CreateBridgedAssetIssuer_Unauthorized() public {
        vm.prank(unauthorizedUser);
        vm.expectRevert("Unauthorized");
        factory.createBridgedAssetIssuer(treasury, address(acl), allowList, reserveToken);
    }
}
