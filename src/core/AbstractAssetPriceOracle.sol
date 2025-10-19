// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import { AbstractContractAuthority } from "./AbstractContractAuthority.sol";

/**
 * @title AbstractAssetPriceOracle
 * @notice Base contract for price oracles with ACL-based access control
 */
abstract contract AbstractAssetPriceOracle is AbstractContractAuthority {

    // Define which ACL level can update prices
    uint64 public constant ORACLE_UPDATER_LEVEL = 2;

    // Maximum staleness allowed: 1 hour
    uint256 public constant MAX_STALENESS = 1 hours;

    mapping(address => uint128) public prices;
    mapping(address => uint256) public lastUpdated;

    // Events
    event PriceUpdated(address indexed token, uint128 newPrice, uint256 timestamp);

    // Errors
    error Unauthorized();
    error InvalidPrice();
    error StalePrice();

    constructor(address aclContract, uint64 allowList ) AbstractContractAuthority( aclContract, allowList) {
        require(aclContract != address(0), "Invalid ACL address");
    }

    /**
     * @notice Update price for a single token
     * @param token The token address
     * @param price The new price multiplier
     */
    function updatePrice(address token, uint128 price) public onlyAuthorized {
        if (token == address(0)) revert InvalidPrice();
        prices[token] = price;
        lastUpdated[token] = block.timestamp;
        emit PriceUpdated(token, price, block.timestamp);
    }

    /**
     * @notice Batch update prices for multiple tokens
     * @param tokens Array of token addresses
     * @param newPrices Array of corresponding prices
     */
    function updatePricesBatch(
        address[] calldata tokens,
        uint128[] calldata newPrices
    ) external onlyAuthorized {
        require(tokens.length == newPrices.length, "Length mismatch");

        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] != address(0)) {
                prices[tokens[i]] = newPrices[i];
                lastUpdated[tokens[i]] = block.timestamp;
                emit PriceUpdated(tokens[i], newPrices[i], block.timestamp);
            }
        }
    }

    /**
     * @notice Get price multiplier for a token with staleness check
     * @param token The token address
     */
    function getMultiplier(address token) public view returns (uint128) {
        uint256 priceAge = block.timestamp - lastUpdated[token];
        if (priceAge > MAX_STALENESS) revert StalePrice();
        return prices[token];
    }

    /**
     * @notice Get price multiplier without staleness check (use with caution)
     * @param token The token address
     */
    function getMultiplierUnchecked(address token) public view returns (uint128 price, uint256 timestamp) {
        return (prices[token], lastUpdated[token]);
    }

    /**
     * @notice Check if a price is stale
     * @param token The token address
     */
    function isPriceStale(address token) public view returns (bool) {
        uint256 priceAge = block.timestamp - lastUpdated[token];
        return priceAge > MAX_STALENESS;
    }
}

interface IAssetPriceOracle {
    function getMultiplier(address token) external view returns (uint128);
}