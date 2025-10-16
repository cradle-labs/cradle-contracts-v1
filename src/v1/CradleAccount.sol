// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {HederaResponseCodes} from "@hedera/HederaResponseCodes.sol";
import {IHederaTokenService} from "@hedera/hedera-token-service/IHederaTokenService.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

/**
CradleAccounts
- act as the main asset holding accounts for all assets in the CradleProtocol
- Interface with tokens across the entire Suite of Cradle Products
- These include
    - Lending and Borrowing Pools
    - Orderbook Trade Settlements
    - Asset Bridging
 */

contract CradleAccount {

    IHederaTokenService constant hts = IHederaTokenService(address(0x167));

    event DepositReceived(address depositor, uint256 amount);
    /**
    the protocol address. The protocol acts as the main controller of this account and can deposit or withdraw assets 
     */
    address public constant PROTOCOL = address(0x1);
    /**
    an offchain identifier tied to this account
     */
    string private controller;
    /**
    bridgers have the ability to bridge assets either on chain or offchain, that means they can make bridge requests to the protocol
     */
    bool public isBridger = false;
    /**
    lockedAsset - mapping of locked assets to amount to prevent withdrawing locked assets for this account
     */
    mapping(address=>uint256) private lockedAssets;


    receive() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }


    modifier onlyProtocol() {
        require(msg.sender == PROTOCOL, "Operation not authorised");
        _;
    }

    constructor(string memory _controller) onlyProtocol() {
        controller = _controller;
        // TODO: handle max associations
    }


    /**
    When withdrawals are occuring the account has to approve itself to spend the amount
     */
    function approveSelfSpend(uint256 amount, address asset) private {
        // TODO: approve spending
    }


    /**
    Depositing to the account can be handled by any wallet 
     */
    function deposit(address asset, uint256 amount) public payable {
        // TODO: check if token's associated then do the association 
        // TODO: approve spending from the user's account
    }

    /**
    Withdrawals handled by protocol to a wallet that's been pre specified offchain
     */
    function withdraw(address asset, uint256 amount, address to) public onlyProtocol() {
        approveSelfSpend(amount, asset);
        transferAsset(to, asset, amount);
    }


    /**
    updateBridgingStatus:
    - set to either true or false to allow briding of assets on chain or off chain
     */
    function updateBridgingStatus(bool status) public onlyProtocol() {
        isBridger = status;
    }


    /**
    transferAsset
     */
    function transferAsset(address to, address asset, uint256 amount) public onlyProtocol() {
        uint256 tradableBalance = getTradableBalance(asset);
        if (amount > tradableBalance) {
            revert("insufficient assets to complete transfer");
        }
        int response = hts.transferFrom(asset, address(this), to, amount);

        if(response != HederaResponseCodes.SUCCESS){
            revert("Failed to transfer assets");
        }
    }

    function getTradableBalance(address asset) public view returns (uint256) {
        uint256 lockedAmount = lockedAssets[asset];
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));
        if (lockedAmount > assetBalance) {
            return 0;  // or revert with error
        }
        return assetBalance - lockedAmount;
    }

    /**
    handles locking of asset amounts
     */
    function lockAsset(address asset, uint256 amount) public onlyProtocol() {
        uint256 tradableBalance = getTradableBalance(asset);
        if(amount > tradableBalance){
            revert("Insufficient unlocked balance to lock");
        }
        lockedAssets[asset] += amount;
    }

    /**
    handles unlocking assets 
     */
    function unlockAsset(address asset, uint256 amount) public onlyProtocol() {
        uint256 totalLocked = lockedAssets[asset];
        require(amount <= totalLocked, "Cannot unlock more than locked");
        lockedAssets[asset] = totalLocked - amount;
    }


}

/**
ICradleAccount
- interface for interaction
 */
interface ICradleAccount {
    function updateBridgingStatus(bool status) external;
    function withdraw(address asset, uint256 amount, address to) external;
    function transferAsset(address to, address asset, uint256 amount) external;
    function lockAsset(address asset, uint256 amount) external;
    function unlockAsset(address asset, uint256 amount) external;
}