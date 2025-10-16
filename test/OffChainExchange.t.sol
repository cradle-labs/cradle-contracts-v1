// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import { Test } from "forge-std/Test.sol";
import {OffChainExchange} from "../src/OffChainExchange.sol";

contract OffChainExchangeTest is Test {

    OffChainExchange public exchange;


    function setUp() public {
        exchange = new OffChainExchange();

    }

    function test_UpdateTokenPriceUSD() public {
        address asset1Address = address(1);
        exchange.updateAssetPriceOracle(asset1Address, 1);
    }

    function test_getTokenPriceUSD() public {
        address asset1Address = address(1);
        exchange.updateAssetPriceOracle(asset1Address, 1);
        uint128 priceUSD = exchange.getPriceUSD(asset1Address);
        assertEq(priceUSD, 1);
    }
    
}