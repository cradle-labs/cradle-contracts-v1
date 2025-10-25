// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { AssetLendingPool } from "./AssetLendingPool.sol";

contract LendingPoolFactory {

    mapping(string=>address) public pools;
    address controller;
    address aclContract;

    modifier onlyAuthorized(){ 
        require(msg.sender == controller, "Unauthorized");
        _;
    }

    constructor(address _aclContract) {
        controller = msg.sender;
        aclContract = _aclContract;
    }


    function createPool(
        uint64 ltv,
        uint64 optimalUtilization,
        uint64 baseRate,
        uint64 slope1,
        uint64 slope2,
        uint64 liquidationThreshold,
        uint64 liquidationDiscount,
        uint64 reserveFactor,
        address lending,
        string memory yieldAsset,
        string memory yieldAssetSymbol,
        string memory lendingPool
    ) payable public onlyAuthorized  {
        AssetLendingPool pool = new AssetLendingPool{value: msg.value}(
            ltv,
            optimalUtilization,
            baseRate,
            slope1,
            slope2,
            liquidationThreshold,
            liquidationDiscount,
            reserveFactor,
            lending,
            yieldAsset,
            yieldAssetSymbol,
            lendingPool,
            aclContract,
            uint64(2)
        );

        pools[lendingPool] = address(pool);
    }


    function getPool(string memory name)public view returns(address) {
        return pools[name];
    }
} 