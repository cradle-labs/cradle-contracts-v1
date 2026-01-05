// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { AccessController } from "../core/AccessController.sol";

contract AccessControllerTest is Test {
    AccessController acl;
    
    address admin;
    address user1;
    address user2;
    address user3;

    event AccessGranted(uint64 indexed level, address indexed account);
    event AccessRevoked(uint64 indexed level, address indexed account);
    event LevelCleared(uint64 indexed level);

    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        
        acl = new AccessController();
    }

    // Constructor Tests
    function test_Constructor_SetsDeployerAsLevel0() public view {
        assertTrue(acl.hasAccess(0, admin));
        assertEq(acl.getLevelCount(0), 1);
    }

    // hasAccess Tests
    function test_HasAccess_ReturnsTrueForExistingAddress() public {
        acl.grantAccess(1, user1);
        assertTrue(acl.hasAccess(1, user1));
    }

    function test_HasAccess_ReturnsFalseForNonExistingAddress() public view {
        assertFalse(acl.hasAccess(1, user1));
    }

    function test_HasAccess_ReturnsFalseForDifferentLevel() public {
        acl.grantAccess(1, user1);
        assertFalse(acl.hasAccess(2, user1));
    }

    // grantAccess Tests
    function test_GrantAccess_AddsAddressToLevel() public {
        vm.expectEmit(true, true, false, true);
        emit AccessGranted(1, user1);
        
        acl.grantAccess(1, user1);
        
        assertTrue(acl.hasAccess(1, user1));
        assertEq(acl.getLevelCount(1), 1);
    }

    function test_GrantAccess_RevertsIfNotLevel0() public {
        vm.prank(user1);
        vm.expectRevert(AccessController.Unauthorized.selector);
        acl.grantAccess(1, user2);
    }

    function test_GrantAccess_RevertsIfAddressIsZero() public {
        vm.expectRevert(AccessController.InvalidLevel.selector);
        acl.grantAccess(1, address(0));
    }

    function test_GrantAccess_RevertsIfAlreadyExists() public {
        acl.grantAccess(1, user1);
        
        vm.expectRevert(AccessController.AlreadyExists.selector);
        acl.grantAccess(1, user1);
    }

    function test_GrantAccess_AllowsSameAddressOnDifferentLevels() public {
        acl.grantAccess(1, user1);
        acl.grantAccess(2, user1);
        
        assertTrue(acl.hasAccess(1, user1));
        assertTrue(acl.hasAccess(2, user1));
    }

    // revokeAccess Tests
    function test_RevokeAccess_RemovesAddressFromLevel() public {
        acl.grantAccess(1, user1);
        
        vm.expectEmit(true, true, false, true);
        emit AccessRevoked(1, user1);
        
        acl.revokeAccess(1, user1);
        
        assertFalse(acl.hasAccess(1, user1));
        assertEq(acl.getLevelCount(1), 0);
    }

    function test_RevokeAccess_RevertsIfNotLevel0() public {
        acl.grantAccess(1, user1);
        
        vm.prank(user1);
        vm.expectRevert(AccessController.Unauthorized.selector);
        acl.revokeAccess(1, user1);
    }

    function test_RevokeAccess_RevertsIfAddressNotFound() public {
        vm.expectRevert(AccessController.AddressNotFound.selector);
        acl.revokeAccess(1, user1);
    }

    function test_RevokeAccess_HandlesMultipleAddresses() public {
        acl.grantAccess(1, user1);
        acl.grantAccess(1, user2);
        acl.grantAccess(1, user3);
        
        acl.revokeAccess(1, user2);
        
        assertTrue(acl.hasAccess(1, user1));
        assertFalse(acl.hasAccess(1, user2));
        assertTrue(acl.hasAccess(1, user3));
        assertEq(acl.getLevelCount(1), 2);
    }

    function test_RevokeAccess_CanRemoveLevel0Address() public {
        acl.grantAccess(0, user1);
        assertEq(acl.getLevelCount(0), 2);
        
        acl.revokeAccess(0, user1);
        
        assertFalse(acl.hasAccess(0, user1));
        assertEq(acl.getLevelCount(0), 1);
    }

    // grantAccessBatch Tests
    function test_GrantAccessBatch_AddsMultipleAddresses() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        
        vm.expectEmit(true, true, false, true);
        emit AccessGranted(1, user1);
        vm.expectEmit(true, true, false, true);
        emit AccessGranted(1, user2);
        vm.expectEmit(true, true, false, true);
        emit AccessGranted(1, user3);
        
        acl.grantAccessBatch(1, users);
        
        assertTrue(acl.hasAccess(1, user1));
        assertTrue(acl.hasAccess(1, user2));
        assertTrue(acl.hasAccess(1, user3));
        assertEq(acl.getLevelCount(1), 3);
    }

    function test_GrantAccessBatch_SkipsZeroAddress() public {
        address[] memory users = new address[](3);
        users[0] = user1;
        users[1] = address(0);
        users[2] = user2;
        
        acl.grantAccessBatch(1, users);
        
        assertTrue(acl.hasAccess(1, user1));
        assertFalse(acl.hasAccess(1, address(0)));
        assertTrue(acl.hasAccess(1, user2));
        assertEq(acl.getLevelCount(1), 2);
    }

    function test_GrantAccessBatch_SkipsDuplicates() public {
        acl.grantAccess(1, user1);
        
        address[] memory users = new address[](2);
        users[0] = user1;
        users[1] = user2;
        
        acl.grantAccessBatch(1, users);
        
        assertEq(acl.getLevelCount(1), 2);
    }

    function test_GrantAccessBatch_RevertsIfNotLevel0() public {
        address[] memory users = new address[](1);
        users[0] = user1;
        
        vm.prank(user1);
        vm.expectRevert(AccessController.Unauthorized.selector);
        acl.grantAccessBatch(1, users);
    }

    // clearLevel Tests
    function test_ClearLevel_RemovesAllAddresses() public {
        acl.grantAccess(1, user1);
        acl.grantAccess(1, user2);
        acl.grantAccess(1, user3);
        
        vm.expectEmit(true, false, false, true);
        emit LevelCleared(1);
        
        acl.clearLevel(1);
        
        assertFalse(acl.hasAccess(1, user1));
        assertFalse(acl.hasAccess(1, user2));
        assertFalse(acl.hasAccess(1, user3));
        assertEq(acl.getLevelCount(1), 0);
    }

    function test_ClearLevel_RevertsIfLevel0() public {
        vm.expectRevert(AccessController.InvalidLevel.selector);
        acl.clearLevel(0);
    }

    function test_ClearLevel_RevertsIfNotLevel0() public {
        vm.prank(user1);
        vm.expectRevert(AccessController.Unauthorized.selector);
        acl.clearLevel(1);
    }

    function test_ClearLevel_WorksOnEmptyLevel() public {
        acl.clearLevel(1);
        assertEq(acl.getLevelCount(1), 0);
    }

    // getLevel Tests
    function test_GetLevel_ReturnsAllAddresses() public {
        acl.grantAccess(1, user1);
        acl.grantAccess(1, user2);
        
        address[] memory addresses = acl.getLevel(1);
        
        assertEq(addresses.length, 2);
        assertEq(addresses[0], user1);
        assertEq(addresses[1], user2);
    }

    function test_GetLevel_ReturnsEmptyArrayForEmptyLevel() public view {
        address[] memory addresses = acl.getLevel(1);
        assertEq(addresses.length, 0);
    }

    // getLevelCount Tests
    function test_GetLevelCount_ReturnsCorrectCount() public {
        assertEq(acl.getLevelCount(1), 0);
        
        acl.grantAccess(1, user1);
        assertEq(acl.getLevelCount(1), 1);
        
        acl.grantAccess(1, user2);
        assertEq(acl.getLevelCount(1), 2);
    }

    // rotateLevel0Key Tests
    function test_RotateLevel0Key_ReplacesKey() public {
        acl.grantAccess(0, user1);
        
        vm.expectEmit(true, true, false, true);
        emit AccessRevoked(0, user1);
        vm.expectEmit(true, true, false, true);
        emit AccessGranted(0, user2);
        
        acl.rotateLevel0Key(user1, user2);
        
        assertFalse(acl.hasAccess(0, user1));
        assertTrue(acl.hasAccess(0, user2));
        assertEq(acl.getLevelCount(0), 2);
    }

    function test_RotateLevel0Key_RevertsIfNotLevel0() public {
        acl.grantAccess(0, user1);
        
        vm.prank(user2);
        vm.expectRevert(AccessController.Unauthorized.selector);
        acl.rotateLevel0Key(user1, user2);
    }

    function test_RotateLevel0Key_RevertsIfNewKeyIsZero() public {
        acl.grantAccess(0, user1);
        
        vm.expectRevert(AccessController.InvalidLevel.selector);
        acl.rotateLevel0Key(user1, address(0));
    }

    function test_RotateLevel0Key_RevertsIfOldKeyNotFound() public {
        vm.expectRevert(AccessController.AddressNotFound.selector);
        acl.rotateLevel0Key(user1, user2);
    }

    function test_RotateLevel0Key_RevertsIfNewKeyAlreadyExists() public {
        acl.grantAccess(0, user1);
        acl.grantAccess(0, user2);
        
        vm.expectRevert(AccessController.AlreadyExists.selector);
        acl.rotateLevel0Key(user1, user2);
    }

    function test_RotateLevel0Key_AllowsRotatingSelf() public {
        acl.rotateLevel0Key(admin, user1);
        
        assertFalse(acl.hasAccess(0, admin));
        assertTrue(acl.hasAccess(0, user1));
    }

    // Integration Tests
    function test_Integration_MultiLevelAccess() public {
        acl.grantAccess(1, user1);
        acl.grantAccess(2, user2);
        acl.grantAccess(3, user3);
        
        assertTrue(acl.hasAccess(1, user1));
        assertTrue(acl.hasAccess(2, user2));
        assertTrue(acl.hasAccess(3, user3));
        
        assertFalse(acl.hasAccess(2, user1));
        assertFalse(acl.hasAccess(3, user2));
        assertFalse(acl.hasAccess(1, user3));
    }

    function test_Integration_FullAccessLifecycle() public {
        // Grant access
        acl.grantAccess(1, user1);
        assertTrue(acl.hasAccess(1, user1));
        
        // Revoke access
        acl.revokeAccess(1, user1);
        assertFalse(acl.hasAccess(1, user1));
        
        // Re-grant access
        acl.grantAccess(1, user1);
        assertTrue(acl.hasAccess(1, user1));
    }

    // Fuzz Tests
    function testFuzz_GrantAccess_WorksForAnyLevel(uint64 level, address account) public {
        vm.assume(account != address(0));
        vm.assume(!acl.hasAccess(level, account));
        
        acl.grantAccess(level, account);
        assertTrue(acl.hasAccess(level, account));
    }

    function testFuzz_RevokeAccess_WorksForAnyLevel(uint64 level, address account) public {
        vm.assume(account != address(0));
        vm.assume(!acl.hasAccess(level, account));
        
        acl.grantAccess(level, account);
        acl.revokeAccess(level, account);
        assertFalse(acl.hasAccess(level, account));
    }

    function testFuzz_ClearLevel_WorksForAnyNonZeroLevel(uint64 level) public {
        vm.assume(level != 0);
        
        acl.grantAccess(level, user1);
        acl.clearLevel(level);
        assertEq(acl.getLevelCount(level), 0);
    }
}