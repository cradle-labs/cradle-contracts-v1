// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { AbstractCradleAssetManager } from "./AbstractCradleAssetManager.sol";
import { CradleBridgedAssetManager } from "./CradleBridgedAssetManager.sol";
import {ICradleAccount, CradleAccount} from "./CradleAccount.sol";
/**
CradleBridgedAssetIssuer
The issuer manages issuing of bridged assets to bridgers as well as buying back assets from bridgers
 */
contract CradleBridgedAssetsIssuer {
    address public PROTOCOL = address(0x1);
    address public stable = address(0x2);
    CradleAccount treasury;
    mapping(string => AbstractCradleAssetManager) public bridgedAssets;


    modifier onlyProtocol(){
        require(
            msg.sender == PROTOCOL,
            "Unauthorised" 
        );
        _;
    }

    constructor(){
        treasury = new CradleAccount("treasury");
    }


    function createBridgedAsset(string memory _name, string memory _symbol) payable public returns (address) {
        CradleBridgedAssetManager asset = new CradleBridgedAssetManager{value: msg.value}(_name, _symbol);
        bridgedAssets[_symbol] = asset;
        return address(asset);
    }

    function lockStable(address user, uint256 amount) public onlyProtocol() {
        ICradleAccount(user).lockAsset(stable, amount);
    }

    function releaseAsset(address user, string memory symbol, uint256 mintAmount, uint256 unlockAmount) public onlyProtocol() {
        AbstractCradleAssetManager asset = bridgedAssets[symbol];
        require(address(asset) != address(0), "Asset does not exist");
        ICradleAccount(user).unlockAsset(stable, unlockAmount);
        ICradleAccount(user).transferAsset(address(treasury), stable, unlockAmount);
        asset.airdropTokens(user, uint64(mintAmount));
    }

    function lockAsset(address user, address asset, uint256 amount) public onlyProtocol() {
        ICradleAccount(user).lockAsset(asset, amount);
    }
    

    function releaseStable(address user, string memory symbol, uint256 burnAmount, uint256 releaseAmount) public onlyProtocol() {
        AbstractCradleAssetManager asset = bridgedAssets[symbol];
        require(address(asset) != address(0), "Asset does not exist");
        ICradleAccount(user).unlockAsset(asset.token(), burnAmount);
        asset.wipe(uint64(burnAmount), user);
        treasury.transferAsset(user, stable, releaseAmount);
    }

}