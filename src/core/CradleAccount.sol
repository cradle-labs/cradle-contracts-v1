// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {HederaResponseCodes} from "@hedera/HederaResponseCodes.sol";
import {IHederaTokenService} from "@hedera/hedera-token-service/IHederaTokenService.sol";
import {HederaTokenService} from "@hedera/hedera-token-service/HederaTokenService.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import { AbstractContractAuthority } from "./AbstractContractAuthority.sol";
/**
 * CradleAccounts
 * - act as the main asset holding accounts for all assets in the CradleProtocol
 * - Interface with tokens across the entire Suite of Cradle Products
 * - These include
 *     - Lending and Borrowing Pools
 *     - Orderbook Trade Settlements
 *     - Asset Bridging
 */
contract CradleAccount is AbstractContractAuthority {
    IHederaTokenService constant hts = IHederaTokenService(address(0x167));

    event DepositReceived(address depositor, uint256 amount);
    /**
     * an offchain identifier tied to this account
     */
    string private controller;
    /**
     * bridgers have the ability to bridge assets either on chain or offchain, that means they can make bridge requests to the protocol
     */
    bool public isBridger = false;
    /**
     * lockedAsset - mapping of locked assets to amount to prevent withdrawing locked assets for this account
     */
    mapping(address => uint256) private lockedAssets;
    /**
     * loans - account loans from different lending pools
     */
    mapping(address => mapping(address => uint256)) public loans;
    /**
     * loan collaterals
     */
    mapping(address => mapping(address => uint256)) public loanCollaterals;
    /**
     * loan borrow indexes
     */
    mapping(address => mapping(address => uint256)) public loanIndexes;

    receive() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }

    constructor(string memory _controller, address aclContract, uint64 allowList) AbstractContractAuthority(aclContract, allowList) {
        controller = _controller;
    }

    function associateToken(address token) public onlyAuthorized {
        int64 responseCode = hts.associateToken(address(this), token);

        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert("Failed to associate token");
        }
    }

    /**
     * When withdrawals are occuring the account has to approve itself to spend the amount
     */
    function approveSelfSpend(uint256 amount, address asset) private {
        int64 responseCode = hts.approve(asset, address(this), amount);

        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert("Failed to associate token");
        }
    }

    /**
     * Depositing to the account can be handled by any wallet
     */
    function deposit(address asset, uint256 amount) public payable {
        hts.approve(asset, msg.sender, amount);
        hts.transferToken(asset, msg.sender, address(this), int64(uint64(amount)));
    }

    /**
     * Withdrawals handled by protocol to a wallet that's been pre specified offchain
     */
    function withdraw(address asset, uint256 amount, address to) public onlyAuthorized {
        transferAsset(to, asset, amount);
    }

    /**
     * updateBridgingStatus:
     * - set to either true or false to allow briding of assets on chain or off chain
     */
    function updateBridgingStatus(bool status) public onlyAuthorized {
        isBridger = status;
    }

    /**
     * transferAsset
     */
    function transferAsset(address to, address asset, uint256 amount) public onlyAuthorized {
        approveSelfSpend(amount, asset);
        uint256 tradableBalance = getTradableBalance(asset);
        if (amount > tradableBalance) {
            revert("insufficient assets to complete transfer");
        }
        int256 response = hts.transferFrom(asset, address(this), to, amount);

        if (response != HederaResponseCodes.SUCCESS) {
            revert("Failed to transfer assets");
        }
    }

    function getTradableBalance(address asset) public view returns (uint256) {
        uint256 lockedAmount = lockedAssets[asset];
        uint256 assetBalance = IERC20(asset).balanceOf(address(this));
        if (lockedAmount > assetBalance) {
            return 0; // or revert with error
        }
        return assetBalance - lockedAmount;
    }

    /**
     * handles locking of asset amounts
     */
    function lockAsset(address asset, uint256 amount) public onlyAuthorized {
        uint256 tradableBalance = getTradableBalance(asset);
        if (amount > tradableBalance) {
            revert("Insufficient unlocked balance to lock");
        }
        lockedAssets[asset] += amount;
    }

    /**
     * handles unlocking assets
     */
    function unlockAsset(address asset, uint256 amount) public onlyAuthorized {
        uint256 totalLocked = lockedAssets[asset];
        require(amount <= totalLocked, "Cannot unlock more than locked");
        lockedAssets[asset] = totalLocked - amount;
    }

    /**
     * addLoanLock to the user and locks their collateral asset
     */
    function addLoanLock(
        address lender,
        address collateral,
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 borrowIndex
    ) public onlyAuthorized {
        loans[lender][collateral] += loanAmount;
        loanCollaterals[lender][collateral] += collateralAmount;
        loanIndexes[lender][collateral] = borrowIndex;
        lockAsset(collateral, collateralAmount);
    }

    /**
     * getLoanAmount
     */
    function getLoanAmount(address lender, address collateral) public view returns (uint256) {
        return loans[lender][collateral];
    }

    /**
     * getCollateral
     */
    function getCollateral(address lender, address collateral) public view returns (uint256) {
        return loanCollaterals[lender][collateral];
    }

    /**
     * getLoanBlockIndex
     */
    function getLoanBlockIndex(address lender, address collateral) public view returns (uint256) {
        return loanIndexes[lender][collateral];
    }

    /**
     * repay a loan, the user unlocks their assets to be tradable
     */
    function removeLoanLock(
        address lender,
        address collateral,
        uint256 loanAmount,
        uint256 collateralAmount
    ) public onlyAuthorized {
        require(loans[lender][collateral] >= loanAmount, "No loans to repay");
        loans[lender][collateral] -= loanAmount;
        loanCollaterals[lender][collateral] -= collateralAmount;
        loanIndexes[lender][collateral] = 0;
        unlockAsset(collateral, collateralAmount);
    }
}

/**
 * ICradleAccount
 * - interface for interaction
 */
interface ICradleAccount {
    function updateBridgingStatus(bool status) external;
    function withdraw(address asset, uint256 amount, address to) external;
    function transferAsset(address to, address asset, uint256 amount) external;
    function lockAsset(address asset, uint256 amount) external;
    function unlockAsset(address asset, uint256 amount) external;
    function addLoanLock(
        address lender,
        address collateral,
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 borrowIndex
    ) external;
    function removeLoanLock(
        address lender,
        address collateral,
        uint256 loanAmount,
        uint256 collateralAmount,
        uint256 borrowIndex
    ) external;
    function getLoanAmount(address lender, address collateral) external view returns (uint256);
    function getCollateral(address lender, address collateral) external view returns (uint256);
    function getLoanBlockIndex(address lender, address collateral) external view returns (uint256);
}
