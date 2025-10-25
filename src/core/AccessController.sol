// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title AccessController
 * @notice Hierarchical access control system with key rotation support
 * @dev acl[0] = super admin level, can manage all other levels
 */
contract AccessController {
    mapping(uint64 => address[]) private acl;

    // Events for transparency
    event AccessGranted(uint64 indexed level, address indexed account);
    event AccessRevoked(uint64 indexed level, address indexed account);
    event LevelCleared(uint64 indexed level);

    // Errors
    error Unauthorized();
    error InvalidLevel();
    error AddressNotFound();
    error AlreadyExists();

    constructor() {
        acl[0].push(msg.sender); // Fixed: push instead of direct assignment
    }

    /**
     * @notice Checks if an address has access at a specific level
     */
    function hasAccess(uint64 level, address account) public view returns (bool) {
        address[] memory addresses = acl[level];
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == account) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Modifier to restrict to level 0 (super admin) only
     */
    modifier onlyLevel0() {
        if (!hasAccess(0, msg.sender)) revert Unauthorized();
        _;
    }

    /**
     * @notice Add address to a specific access level
     * @dev Only level 0 can call this
     */
    function grantAccess(uint64 level, address account) external onlyLevel0 {
        if (account == address(0)) revert InvalidLevel();
        if (hasAccess(level, account)) revert AlreadyExists();

        acl[level].push(account);
        emit AccessGranted(level, account);
    }

    /**
     * @notice Remove address from a specific access level
     * @dev Only level 0 can call this
     */
    function revokeAccess(uint64 level, address account) external onlyLevel0 {
        address[] storage addresses = acl[level];

        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == account) {
                // Move last element to the position being removed
                addresses[i] = addresses[addresses.length - 1];
                addresses.pop();
                emit AccessRevoked(level, account);
                return;
            }
        }

        revert AddressNotFound();
    }

    /**
     * @notice Batch grant access to multiple addresses
     */
    function grantAccessBatch(uint64 level, address[] calldata accounts) external onlyLevel0 {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0) && !hasAccess(level, accounts[i])) {
                acl[level].push(accounts[i]);
                emit AccessGranted(level, accounts[i]);
            }
        }
    }

    /**
     * @notice Clear all addresses from a specific level
     * @dev Use with caution! Cannot clear level 0 to prevent lockout
     */
    function clearLevel(uint64 level) external onlyLevel0 {
        if (level == 0) revert InvalidLevel(); // Prevent lockout
        delete acl[level];
        emit LevelCleared(level);
    }

    /**
     * @notice Get all addresses at a specific level
     */
    function getLevel(uint64 level) external view returns (address[] memory) {
        return acl[level];
    }

    /**
     * @notice Get number of addresses at a specific level
     */
    function getLevelCount(uint64 level) external view returns (uint256) {
        return acl[level].length;
    }

    /**
     * @notice Emergency key rotation - replace a level 0 address
     * @dev This is for key compromise scenarios
     */
    function rotateLevel0Key(address oldKey, address newKey) external onlyLevel0 {
        if (newKey == address(0)) revert InvalidLevel();
        if (!hasAccess(0, oldKey)) revert AddressNotFound();
        if (hasAccess(0, newKey)) revert AlreadyExists();

        address[] storage level0 = acl[0];

        for (uint256 i = 0; i < level0.length; i++) {
            if (level0[i] == oldKey) {
                level0[i] = newKey;
                emit AccessRevoked(0, oldKey);
                emit AccessGranted(0, newKey);
                return;
            }
        }
    }
}
