// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CradleAccount} from "../core/CradleAccount.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";
import {MockERC20} from "./utils/MockERC20.sol";

contract CradleAccountTest is Test {
    CradleAccount account;
    AccessController acl;
    MockHTS mockHTS;
    MockERC20 token1;

    address admin;
    address user1;
    address user2;
    address constant HTS_PRECOMPILE = address(0x167);

    event DepositReceived(address depositor, uint256 amount);
    event TokenAssociated(address indexed token);
    event AssetLocked(address indexed asset, uint256 amount, uint256 totalLocked);
    event AssetUnlocked(address indexed asset, uint256 amount, uint256 totalLocked);

    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        acl = new AccessController();
        acl.grantAccess(1, admin);

        account = new CradleAccount("controller123", address(acl), 1);

        // Create a mock ERC20 token and give the account some balance
        token1 = new MockERC20("Test Token", "TEST");
        token1.mint(address(account), 10000);
    }

    // Constructor Tests
    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(account.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowList() public view {
        assertEq(account.controlAllowList(), 1);
    }

    function test_Constructor_InitializesNotBridger() public view {
        assertFalse(account.isBridger());
    }

    // Receive Function Tests
    function test_Receive_AcceptsEther() public {
        vm.deal(user1, 1 ether);

        vm.expectEmit(true, false, false, true);
        emit DepositReceived(user1, 0.5 ether);

        vm.prank(user1);
        (bool success,) = address(account).call{value: 0.5 ether}("");

        assertTrue(success);
        assertEq(address(account).balance, 0.5 ether);
    }

    // associateToken Tests
    function test_AssociateToken_SucceedsWithAuthorization() public {
        address newToken = makeAddr("newToken");
        vm.expectEmit(true, false, false, true);
        emit TokenAssociated(newToken);

        account.associateToken(newToken);
    }

    function test_AssociateToken_RevertsWithoutAuthorization() public {
        address newToken = makeAddr("newToken");
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        account.associateToken(newToken);
    }

    // lockAsset Tests
    function test_LockAsset_SucceedsWithAuthorization() public {
        vm.expectEmit(true, false, false, true);
        emit AssetLocked(address(token1), 1000, 1000);

        account.lockAsset(address(token1), 1000);
    }

    function test_LockAsset_IncreasesTotalLocked() public {
        vm.expectEmit(true, false, false, true);
        emit AssetLocked(address(token1), 1000, 1000);
        account.lockAsset(address(token1), 1000);

        vm.expectEmit(true, false, false, true);
        emit AssetLocked(address(token1), 500, 1500);
        account.lockAsset(address(token1), 500);
    }

    function test_LockAsset_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        account.lockAsset(address(token1), 1000);
    }

    // unlockAsset Tests
    function test_UnlockAsset_SucceedsWithAuthorization() public {
        account.lockAsset(address(token1), 1000);

        vm.expectEmit(true, false, false, true);
        emit AssetUnlocked(address(token1), 500, 500);

        account.unlockAsset(address(token1), 500);
    }

    function test_UnlockAsset_DecreasesTotalLocked() public {
        account.lockAsset(address(token1), 1000);

        vm.expectEmit(true, false, false, true);
        emit AssetUnlocked(address(token1), 300, 700);
        account.unlockAsset(address(token1), 300);
    }

    function test_UnlockAsset_RevertsWithoutAuthorization() public {
        account.lockAsset(address(token1), 1000);

        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        account.unlockAsset(address(token1), 500);
    }

    function test_UnlockAsset_RevertsIfInsufficientLocked() public {
        account.lockAsset(address(token1), 1000);

        vm.expectRevert("Cannot unlock more than locked");
        account.unlockAsset(address(token1), 1500);
    }

    // getTradableBalance Tests (public view function)
    function test_GetTradableBalance_ReturnsCorrectAmount() public view {
        uint256 balance = account.getTradableBalance(address(token1));
        assertEq(balance, 10000); // Initial minted balance
    }

    // Integration Tests
    function test_Integration_LockAndUnlockMultipleAssets() public {
        MockERC20 token2 = new MockERC20("Token 2", "TK2");
        token2.mint(address(account), 5000);

        vm.expectEmit(true, false, false, true);
        emit AssetLocked(address(token1), 1000, 1000);
        account.lockAsset(address(token1), 1000);

        vm.expectEmit(true, false, false, true);
        emit AssetLocked(address(token2), 2000, 2000);
        account.lockAsset(address(token2), 2000);

        vm.expectEmit(true, false, false, true);
        emit AssetUnlocked(address(token1), 500, 500);
        account.unlockAsset(address(token1), 500);

        vm.expectEmit(true, false, false, true);
        emit AssetUnlocked(address(token2), 1000, 1000);
        account.unlockAsset(address(token2), 1000);
    }
}
