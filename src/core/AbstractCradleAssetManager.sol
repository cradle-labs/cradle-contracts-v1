// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {HederaTokenService} from "@hedera/hedera-token-service/HederaTokenService.sol";
import {HederaResponseCodes} from "@hedera/HederaResponseCodes.sol";
import {IHederaTokenService} from "@hedera/hedera-token-service/IHederaTokenService.sol";
import {KeyHelper} from "@hedera/hedera-token-service/KeyHelper.sol";
import {ExpiryHelper} from "@hedera/hedera-token-service/ExpiryHelper.sol";
import { AbstractContractAuthority } from "./AbstractContractAuthority.sol";
/**
 * AbstractCradleAssetManager
 * - This abstract contract offers an interface to be used by all other cradle issued contracts
 * - these include:
 * - CradleBridgedAssetManager
 * - CradleNativeAssetManager
 * - CradleLendingAssetManager
 */
abstract contract AbstractCradleAssetManager is HederaTokenService, KeyHelper, ExpiryHelper, AbstractContractAuthority {
    address public token;

    constructor(string memory _name, string memory _symbol, address aclContract, uint64 allowList) payable AbstractContractAuthority(aclContract, allowList) {
        IHederaTokenService.HederaToken memory tokenDetails;
        tokenDetails.name = _name;
        tokenDetails.symbol = _symbol;
        tokenDetails.treasury = address(this);
        IHederaTokenService.Expiry memory expiry;
        expiry.autoRenewAccount = address(this);
        expiry.autoRenewPeriod = 7890000;
        tokenDetails.expiry = expiry;

        IHederaTokenService.TokenKey[] memory keys = new IHederaTokenService.TokenKey[](7);

        keys[0] = getSingleKey(KeyType.ADMIN, KeyValueType.CONTRACT_ID, address(this));
        keys[1] = getSingleKey(KeyType.KYC, KeyValueType.CONTRACT_ID, address(this));
        keys[2] = getSingleKey(KeyType.FREEZE, KeyValueType.CONTRACT_ID, address(this));
        keys[3] = getSingleKey(KeyType.WIPE, KeyValueType.CONTRACT_ID, address(this));
        keys[4] = getSingleKey(KeyType.SUPPLY, KeyValueType.CONTRACT_ID, address(this));
        keys[5] = getSingleKey(KeyType.FEE, KeyValueType.CONTRACT_ID, address(this));
        keys[6] = getSingleKey(KeyType.PAUSE, KeyValueType.CONTRACT_ID, address(this));

        tokenDetails.tokenKeys = keys;

        (int256 response, address token_address) = HederaTokenService.createFungibleToken(tokenDetails, 0, 8);

        if (response != HederaResponseCodes.SUCCESS) {
            revert("Failed to create token");
        }

        token = token_address;
    }

    /**
     * Protocol handles minting of the assets
     */
    function mint(uint64 amount) public onlyAuthorized {
        (int256 _res,,) = HederaTokenService.mintToken(token, int64(amount), new bytes[](0));

        if (_res != HederaResponseCodes.SUCCESS) {
            revert("Failed to mint asset");
        }
    }

    /**
     * Protocol handles burning of the asset
     */
    function burn(uint64 amount) public onlyAuthorized {
        (int256 _res, ) = HederaTokenService.burnToken(token, int64(amount), new int64[](0));

        if (_res != HederaResponseCodes.SUCCESS) {
            revert("Failed to burn asset");
        }
    }

    /**
     * Wipes tokens from a holder's account without needing to transfer back to the manager before triggering the wipe
     */
    function wipe(uint64 amount, address account) public onlyAuthorized {
        int256 _res = HederaTokenService.wipeTokenAccount(token, account, int64(amount));

        if (_res != HederaResponseCodes.SUCCESS) {
            revert("Failed to wipe asset from the users account");
        }
    }

    // function selfAssociate() public {
    //     int256 res = HederaTokenService.associateToken(msg.sender, token);

    //     if(res != HederaResponseCodes.SUCCESS) {
    //         revert("Association failue");
    //     }
    // }

    /**
     * handles mint and token transfer in a single transaction
     */
    // function airdropTokens(address target, uint64 amount) public onlyAuthorized {

    //     IHederaTokenService.AccountAmount memory recipientAccount;
    //     recipientAccount.accountID = target;
    //     recipientAccount.amount = int64(amount);

    //     IHederaTokenService.AccountAmount memory senderAccount;
    //     senderAccount.accountID = address(this);
    //     senderAccount.amount = -int64(amount);

    //     IHederaTokenService.TokenTransferList memory transferList;

    //     transferList.token = token;
    //     transferList.transfers = new IHederaTokenService.AccountAmount[](2);
    //     transferList.transfers[0] = senderAccount;
    //     transferList.transfers[1] = recipientAccount;

    //     IHederaTokenService.TokenTransferList[] memory airdropList = new IHederaTokenService.TokenTransferList[](1);
    //     airdropList[0] = transferList;

    //     int256 responseCode = hts.airdropTokens(airdropList);

    //     if (responseCode != HederaResponseCodes.SUCCESS) {
    //         revert("Failed to airdrop tokens");
    //     }
    // }


    function transferTokens(address target, uint64 amount) public onlyAuthorized {
        int256 responseCode = HederaTokenService.transferToken(token, address(this), target, int64(amount));
        
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert("Failed to transfer tokens");
        }
    }

    function airdropTokens(address target, uint64 amount) public onlyAuthorized {
        mint(amount);
        transferTokens( target, amount);
    }
}
