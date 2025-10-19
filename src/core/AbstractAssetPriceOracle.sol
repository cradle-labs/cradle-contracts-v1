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
    
    mapping(address => uint128) public prices;

    // Events
    event PriceUpdated(address indexed token, uint128 newPrice);
    
    // Errors
    error Unauthorized();
    error InvalidPrice();

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
        emit PriceUpdated(token, price);
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
                emit PriceUpdated(tokens[i], newPrices[i]);
            }
        }
    }

    /**
     * @notice Get price multiplier for a token
     * @param token The token address
     * @return The price multiplier
     */
    function getMultiplier(address token) public view returns (uint128) {
        return prices[token];
    }
}

interface IAssetPriceOracle {
    function getMultiplier(address token) external view returns (uint128);
}