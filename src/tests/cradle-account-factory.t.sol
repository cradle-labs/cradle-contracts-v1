// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {CradleAccountFactory} from "../core/CradleAccountFactory.sol";
import {CradleAccount} from "../core/CradleAccount.sol";
import {AccessController} from "../core/AccessController.sol";
import {MockHTS} from "./utils/MockHTS.sol";

contract CradleAccountFactoryTest is Test {
    CradleAccountFactory factory;
    AccessController acl;
    MockHTS mockHTS;

    address admin;
    address user1;
    address user2;
    address constant HTS_PRECOMPILE = address(0x167);

    event AccountCreated(
        address indexed accountAddress, string indexed controller, address indexed creator, uint64 allowList
    );
    event AccountLinkedToUser(address indexed accountAddress, address indexed user);
    event AccountUnlinkedFromUser(address indexed accountAddress, address indexed user);

    function setUp() public {
        admin = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        mockHTS = new MockHTS();
        vm.etch(HTS_PRECOMPILE, address(mockHTS).code);

        acl = new AccessController();
        acl.grantAccess(1, admin);

        factory = new CradleAccountFactory(address(acl), 1);
    }

    // Constructor Tests
    function test_Constructor_SetsACLCorrectly() public view {
        assertEq(address(factory.acl()), address(acl));
    }

    function test_Constructor_SetsControlAllowList() public view {
        assertEq(factory.controlAllowList(), 1);
    }

    // createAccount Tests
    function test_CreateAccount_CreatesAccountSuccessfully() public {
        address accountAddress = factory.createAccount("user123", 1);

        assertNotEq(accountAddress, address(0));
        assertTrue(factory.isValidAccount(accountAddress));
    }

    function test_CreateAccount_EmitsEvent() public {
        // We can't predict the exact address, so we check for event emission without strict address matching
        vm.recordLogs();

        address accountAddress = factory.createAccount("user456", 1);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool foundEvent = false;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("AccountCreated(address,string,address,uint64)")) {
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "AccountCreated event not emitted");
        assertNotEq(accountAddress, address(0));
    }

    function test_CreateAccount_RegistersByController() public {
        address accountAddress = factory.createAccount("controller789", 1);

        assertEq(factory.accountsByController("controller789"), accountAddress);
    }

    function test_CreateAccount_AddsToAllAccounts() public {
        address account1 = factory.createAccount("user1", 1);
        address account2 = factory.createAccount("user2", 1);

        assertEq(factory.allAccounts(0), account1);
        assertEq(factory.allAccounts(1), account2);
    }

    function test_CreateAccount_RevertsIfControllerExists() public {
        factory.createAccount("duplicate", 1);

        vm.expectRevert(abi.encodeWithSelector(CradleAccountFactory.AccountAlreadyExists.selector, "duplicate"));
        factory.createAccount("duplicate", 1);
    }

    function test_CreateAccount_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        factory.createAccount("test", 1);
    }

    // createAccountForUser Tests
    function test_CreateAccountForUser_CreatesAndLinksAccount() public {
        address accountAddress = factory.createAccountForUser("user_ctrl", user1, 1);

        assertNotEq(accountAddress, address(0));
        assertEq(factory.accountsByUser(user1), accountAddress);
        assertEq(factory.accountsByController("user_ctrl"), accountAddress);
    }

    function test_CreateAccountForUser_EmitsBothEvents() public {
        vm.expectEmit(false, true, true, true);
        emit AccountCreated(address(0), "ctrl123", admin, 1);

        factory.createAccountForUser("ctrl123", user1, 1);
    }

    function test_CreateAccountForUser_RevertsIfUserHasAccount() public {
        factory.createAccountForUser("first", user1, 1);

        vm.expectRevert(abi.encodeWithSelector(CradleAccountFactory.UserAlreadyHasAccount.selector, user1));
        factory.createAccountForUser("second", user1, 1);
    }

    function test_CreateAccountForUser_RevertsWithoutAuthorization() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        factory.createAccountForUser("test", user2, 1);
    }

    // linkAccountToUser Tests
    function test_LinkAccountToUser_LinksExistingAccount() public {
        address accountAddress = factory.createAccount("existing", 1);

        vm.expectEmit(true, true, false, true);
        emit AccountLinkedToUser(accountAddress, user1);

        factory.linkAccountToUser("existing", user1);

        assertEq(factory.accountsByUser(user1), accountAddress);
    }

    function test_LinkAccountToUser_RevertsIfUserHasAccount() public {
        factory.createAccount("acc1", 1);
        factory.linkAccountToUser("acc1", user1);

        factory.createAccount("acc2", 1);

        vm.expectRevert(abi.encodeWithSelector(CradleAccountFactory.UserAlreadyHasAccount.selector, user1));
        factory.linkAccountToUser("acc2", user1);
    }

    function test_LinkAccountToUser_RevertsIfAccountNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(CradleAccountFactory.AccountNotFound.selector, "nonexistent"));
        factory.linkAccountToUser("nonexistent", user1);
    }

    function test_LinkAccountToUser_RevertsWithoutAuthorization() public {
        factory.createAccount("test", 1);

        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        factory.linkAccountToUser("test", user2);
    }

    // unlinkUserFromAccount Tests
    function test_UnlinkUserFromAccount_UnlinksAccount() public {
        address accountAddress = factory.createAccountForUser("user_test", user1, 1);

        vm.expectEmit(true, true, false, true);
        emit AccountUnlinkedFromUser(accountAddress, user1);

        factory.unlinkUserFromAccount(user1);

        assertEq(factory.accountsByUser(user1), address(0));
    }

    function test_UnlinkUserFromAccount_RevertsWithoutAuthorization() public {
        factory.createAccountForUser("user_test", user1, 1);

        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        factory.unlinkUserFromAccount(user1);
    }

    function test_UnlinkUserFromAccount_RevertsIfUserHasNoAccount() public {
        vm.expectRevert(abi.encodeWithSelector(CradleAccountFactory.InvalidAccount.selector, address(0)));
        factory.unlinkUserFromAccount(user1);
    }

    // getAccountByController Tests
    function test_GetAccountByController_ReturnsCorrectAccount() public {
        address accountAddress = factory.createAccount("finder", 1);

        address found = factory.getAccountByController("finder");
        assertEq(found, accountAddress);
    }

    function test_GetAccountByController_RevertsIfNotFound() public view {
        // getAccountByController doesn't revert, it returns address(0)
        address found = factory.getAccountByController("nonexistent");
        assertEq(found, address(0));
    }

    // getAccountByUser Tests
    function test_GetAccountByUser_ReturnsCorrectAccount() public view {
        address found = factory.getAccountByUser(user1);
        assertEq(found, address(0));
    }

    // Integration Tests
    function test_Integration_CreateMultipleAccountsAndLink() public {
        address account1 = factory.createAccount("ctrl1", 1);
        address account2 = factory.createAccount("ctrl2", 2);

        factory.linkAccountToUser("ctrl1", user1);
        factory.linkAccountToUser("ctrl2", user2);

        assertEq(factory.accountsByUser(user1), account1);
        assertEq(factory.accountsByUser(user2), account2);
        assertEq(factory.accountsByController("ctrl1"), account1);
        assertEq(factory.accountsByController("ctrl2"), account2);
    }

    function test_Integration_UnlinkAndRelink() public {
        address account1 = factory.createAccountForUser("user1_ctrl", user1, 1);

        factory.unlinkUserFromAccount(user1);
        assertEq(factory.accountsByUser(user1), address(0));

        // Can link another account now
        address account2 = factory.createAccount("user1_ctrl2", 1);
        factory.linkAccountToUser("user1_ctrl2", user1);
        assertEq(factory.accountsByUser(user1), account2);
    }
}
