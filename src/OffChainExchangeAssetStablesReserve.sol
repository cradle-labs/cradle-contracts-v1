// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {HederaTokenService} from "@hedera/hedera-token-service/HederaTokenService.sol";
import {HederaResponseCodes} from "@hedera/HederaResponseCodes.sol";
import {IHederaTokenService} from "@hedera/hedera-token-service/IHederaTokenService.sol";
import {KeyHelper} from "@hedera/hedera-token-service/KeyHelper.sol";
import {IHRC719} from "@hedera/hedera-token-service/IHRC719.sol";
import {Strings} from "@openzeppelin/utils/Strings.sol";
import { IOffChainExchange } from "./OffChainExchange.sol";

contract OffChainExchangeAssetStablesReserve {
    address stable;
    address asset; 
    address exchange;
    IHederaTokenService constant hts = IHederaTokenService(address(0x167));


    modifier onlyAdmin() {
        require(
            msg.sender == exchange || msg.sender == address(this), "Unauthorised execution"
        );
        _;
    }

    constructor(address _asset, address _stable){
        uint256 responseCode = IHRC719(_stable).associate();

        if (int32(uint32(responseCode)) != HederaResponseCodes.SUCCESS){
            revert("Failed to setup stable token association");
        }

        asset = _asset;
        exchange = msg.sender;
    }


    function grantAllowanceToExchange(uint256 amount) private onlyAdmin() {
        int64 responseCode = hts.approve(stable, exchange, amount);
        if(responseCode != HederaResponseCodes.SUCCESS){
            revert("Failed to grant allowance to exchange");
        }
    }

    function grantAllowanceToSelf(uint256 amount) private onlyAdmin() {
        int64 responseCode = hts.approve(stable,  address(this), amount);
        if(responseCode != HederaResponseCodes.SUCCESS){
            revert("Failed to grant allowance to self");
        }
    }

    // amount in asset oracle stores multiplier
    function withdraw(uint128 amount, address account) public onlyAdmin() {
        IOffChainExchange exchange_contract = IOffChainExchange(exchange);
        uint128 asset_stable_multiplier = exchange_contract.getStableMultiplier(token);
        uint256 stable_amount = amount * asset_stable_multiplier;
        grantAllowanceToSelf(stable_amount);
        int64 responseCode = hts.transferFrom(stable, address(this), account, stable_amount);
        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert("Withdrawal failed");
        }
    }
}