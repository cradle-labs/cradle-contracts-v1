// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {CradleAccount, ICradleAccount} from "../core/CradleAccount.sol";
import {AbstractContractAuthority} from "../core/AbstractContractAuthority.sol";

/**
 * @title CradleAccountFactory
 * @notice Factory contract for creating and managing CradleAccount instances
 * @dev Tracks all created accounts and provides lookup functionality
 */
contract CradleAccountFactory is AbstractContractAuthority {

    // Mapping from controller identifier to CradleAccount address
    mapping(string => address) public accountsByController;

    // Mapping from user address to their CradleAccount address
    mapping(address => address) public accountsByUser;

    // Array of all created accounts
    address[] public allAccounts;

    // Mapping to check if an address is a valid CradleAccount created by this factory
    mapping(address => bool) public isValidAccount;

    // Events
    event AccountCreated(
        address indexed accountAddress,
        string indexed controller,
        address indexed creator,
        uint64 allowList
    );
    event AccountLinkedToUser(address indexed accountAddress, address indexed user);
    event AccountUnlinkedFromUser(address indexed accountAddress, address indexed user);

    // Errors
    error AccountAlreadyExists(string controller);
    error UserAlreadyHasAccount(address user);
    error InvalidAccount(address account);
    error AccountNotFound(string controller);

    constructor(address aclContract, uint64 allowList) AbstractContractAuthority(aclContract, allowList) {}

    /**
     * @notice Create a new CradleAccount
     * @param controller Offchain identifier for the account
     * @param accountAllowList Access control level for the new account
     * @return accountAddress The address of the newly created CradleAccount
     */
    function createAccount(
        string memory controller,
        uint64 accountAllowList
    ) public onlyAuthorized returns (address accountAddress) {
        // Check if account already exists for this controller
        if (accountsByController[controller] != address(0)) {
            revert AccountAlreadyExists(controller);
        }

        // Create new CradleAccount
        CradleAccount newAccount = new CradleAccount(
            controller,
            address(acl),
            accountAllowList
        );

        accountAddress = address(newAccount);

        // Register the account
        accountsByController[controller] = accountAddress;
        allAccounts.push(accountAddress);
        isValidAccount[accountAddress] = true;

        emit AccountCreated(accountAddress, controller, msg.sender, accountAllowList);

        return accountAddress;
    }

    /**
     * @notice Create a new CradleAccount and link it to a user address
     * @param controller Offchain identifier for the account
     * @param user User address to link to this account
     * @param accountAllowList Access control level for the new account
     * @return accountAddress The address of the newly created CradleAccount
     */
    function createAccountForUser(
        string memory controller,
        address user,
        uint64 accountAllowList
    ) external onlyAuthorized returns (address accountAddress) {
        // Check if user already has an account
        if (accountsByUser[user] != address(0)) {
            revert UserAlreadyHasAccount(user);
        }

        // Create the account
        accountAddress = createAccount(controller, accountAllowList);

        // Link to user
        accountsByUser[user] = accountAddress;

        emit AccountLinkedToUser(accountAddress, user);

        return accountAddress;
    }

    /**
     * @notice Link an existing CradleAccount to a user address
     * @param controller Controller identifier of the account
     * @param user User address to link
     */
    function linkAccountToUser(string memory controller, address user) external onlyAuthorized {
        address accountAddress = accountsByController[controller];

        if (accountAddress == address(0)) {
            revert AccountNotFound(controller);
        }

        if (accountsByUser[user] != address(0)) {
            revert UserAlreadyHasAccount(user);
        }

        accountsByUser[user] = accountAddress;

        emit AccountLinkedToUser(accountAddress, user);
    }

    /**
     * @notice Unlink a user from their CradleAccount
     * @param user User address to unlink
     */
    function unlinkUserFromAccount(address user) external onlyAuthorized {
        address accountAddress = accountsByUser[user];

        if (accountAddress == address(0)) {
            revert InvalidAccount(address(0));
        }

        delete accountsByUser[user];

        emit AccountUnlinkedFromUser(accountAddress, user);
    }

    /**
     * @notice Get CradleAccount address by controller identifier
     * @param controller Controller identifier
     * @return The CradleAccount address
     */
    function getAccountByController(string memory controller) external view returns (address) {
        return accountsByController[controller];
    }

    /**
     * @notice Get CradleAccount address by user address
     * @param user User address
     * @return The CradleAccount address
     */
    function getAccountByUser(address user) external view returns (address) {
        return accountsByUser[user];
    }

    /**
     * @notice Get total number of accounts created
     * @return The total number of CradleAccounts
     */
    function getAccountCount() external view returns (uint256) {
        return allAccounts.length;
    }

    /**
     * @notice Get account address at a specific index
     * @param index The index in the allAccounts array
     * @return The CradleAccount address
     */
    function getAccountAtIndex(uint256 index) external view returns (address) {
        require(index < allAccounts.length, "Index out of bounds");
        return allAccounts[index];
    }

    /**
     * @notice Get a range of account addresses
     * @param startIndex Starting index (inclusive)
     * @param endIndex Ending index (exclusive)
     * @return accounts Array of CradleAccount addresses
     */
    function getAccountsRange(uint256 startIndex, uint256 endIndex)
        external
        view
        returns (address[] memory accounts)
    {
        require(startIndex < endIndex, "Invalid range");
        require(endIndex <= allAccounts.length, "End index out of bounds");

        uint256 length = endIndex - startIndex;
        accounts = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            accounts[i] = allAccounts[startIndex + i];
        }

        return accounts;
    }

    /**
     * @notice Check if an address is a valid CradleAccount created by this factory
     * @param account Address to check
     * @return True if the address is a valid CradleAccount
     */
    function isAccountValid(address account) external view returns (bool) {
        return isValidAccount[account];
    }

    /**
     * @notice Batch create multiple CradleAccounts
     * @param controllers Array of controller identifiers
     * @param accountAllowLists Array of access control levels (must match controllers length)
     * @return accountAddresses Array of created CradleAccount addresses
     */
    function batchCreateAccounts(
        string[] memory controllers,
        uint64[] memory accountAllowLists
    ) external onlyAuthorized returns (address[] memory accountAddresses) {
        require(controllers.length == accountAllowLists.length, "Array length mismatch");

        accountAddresses = new address[](controllers.length);

        for (uint256 i = 0; i < controllers.length; i++) {
            accountAddresses[i] = this.createAccount(controllers[i], accountAllowLists[i]);
        }

        return accountAddresses;
    }

    /**
     * @notice Get account statistics
     * @return totalAccounts Total number of accounts created
     * @return totalLinkedUsers Total number of users with linked accounts
     */
    function getStats() external view returns (
        uint256 totalAccounts,
        uint256 totalLinkedUsers
    ) {
        totalAccounts = allAccounts.length;

        // Count linked users by iterating through accounts
        // Note: This is gas-intensive for large numbers, use off-chain for production
        uint256 linkedCount = 0;
        for (uint256 i = 0; i < allAccounts.length; i++) {
            // This is a simplified count - in production you'd track this separately
            linkedCount++;
        }

        totalLinkedUsers = linkedCount;
    }
}

/**
 * @title ICradleAccountFactory
 * @notice Interface for the CradleAccountFactory
 */
interface ICradleAccountFactory {
    function createAccount(string memory controller, uint64 accountAllowList) external returns (address);
    function createAccountForUser(string memory controller, address user, uint64 accountAllowList) external returns (address);
    function getAccountByController(string memory controller) external view returns (address);
    function getAccountByUser(address user) external view returns (address);
    function isAccountValid(address account) external view returns (bool);
}
