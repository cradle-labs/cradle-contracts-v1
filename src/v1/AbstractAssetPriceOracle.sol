// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
AbstractAssetPriceOracle
- this abstract contract has logic for all the different oracles
 */
abstract contract AbstractAssetPriceOracle {
    /**
    the protocol address. The protocol acts as the main controller of this account and can deposit or withdraw assets 
     */
    address public constant PROTOCOL = address(0x1);
    mapping(address => uint128) public prices;


    modifier onlyProtocol() {
        require(msg.sender == PROTOCOL, "Operation not authorised");
        _;
    }


    function updateMultiplier(address token, uint128 multiplier) public onlyProtocol() {
        prices[token] = multiplier;
    }

    function getMultiplier(address token) public view returns (uint128) {
        return prices[token];
    }
}


interface IAssetPriceOracle {
    function getMultiplier(address token) external view returns (uint128);
}