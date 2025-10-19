// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";
import {ICradleAccount, CradleAccount} from "./CradleAccount.sol";
import { AbstractContractAuthority } from "./AbstractContractAuthority.sol";
/**
 * AbstractAssetIssuer
 * The issuer manages issuing of bridged assets to bridgers as well as buying back assets from bridgers
 */

abstract contract AbstractAssetsIssuer is AbstractContractAuthority {

    address public reserveToken;

    CradleAccount treasury;
    mapping(string => AbstractCradleAssetManager) public bridgedAssets;

    constructor(address aclContract, uint64 allowList, address _reserveToken) AbstractContractAuthority(aclContract, allowList) {
        treasury = new CradleAccount("treasury", aclContract, allowList);
        reserveToken = _reserveToken;
    }

    function _createAsset(string memory _name, string memory _symbol, address aclContract, uint64 allowList) internal virtual returns (AbstractCradleAssetManager);

    function createAsset(string memory _name, string memory _symbol, address aclContract, uint64 allowList) public payable onlyAuthorized returns (address) {
        AbstractCradleAssetManager asset = _createAsset(_name, _symbol, aclContract, allowList);
        bridgedAssets[_symbol] = asset;
        return address(asset);
    }

    function lockReserves(address user, uint256 amount) public onlyAuthorized {
        // TODO: change this to just take out the money and place it in the reserve account 
        ICradleAccount(user).lockAsset(reserveToken, amount);
    }

    function releaseAsset(address user, string memory symbol, uint256 mintAmount, uint256 unlockAmount)
        public
        onlyAuthorized
    {
        AbstractCradleAssetManager asset = bridgedAssets[symbol];
        require(address(asset) != address(0), "Asset does not exist");
        ICradleAccount(user).unlockAsset(reserveToken, unlockAmount);
        ICradleAccount(user).transferAsset(address(treasury), reserveToken, unlockAmount);
        asset.airdropTokens(user, uint64(mintAmount));
    }

    function lockAsset(address user, address asset, uint256 amount) public onlyAuthorized {
        ICradleAccount(user).lockAsset(asset, amount);
    }

    function releaseReserves(address user, string memory symbol, uint256 burnAmount, uint256 releaseAmount)
        public
        onlyAuthorized
    {
        // TODO: change this to transfer from the reserveAccount to the user
        AbstractCradleAssetManager asset = bridgedAssets[symbol];
        require(address(asset) != address(0), "Asset does not exist");
        ICradleAccount(user).unlockAsset(asset.token(), burnAmount);
        asset.wipe(uint64(burnAmount), user);
        treasury.transferAsset(user, reserveToken, releaseAmount);
    }
}
