// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {NativeAssetIssuer} from "./NativeAssetIssuer.sol";
import {AbstractContractAuthority} from "./AbstractContractAuthority.sol";

/**
 * @title NativeAssetIssuerFactory
 * @notice Factory contract for creating NativeAssetIssuer contracts
 */
contract NativeAssetIssuerFactory is AbstractContractAuthority {
    event IssuerCreated(address indexed issuer, address indexed treasury, address indexed reserveToken);

    mapping(address => bool) public isIssuer;

    constructor(address aclContract, uint64 allowList) AbstractContractAuthority(aclContract, allowList) {}

    /**
     * @notice Creates a new NativeAssetIssuer
     * @param treasury The treasury address for the issuer
     * @param aclContract The access control contract address
     * @param allowList The allow list identifier
     * @param reserveToken The reserve token address
     * @return The address of the newly created NativeAssetIssuer
     */
    function createNativeAssetIssuer(address treasury, address aclContract, uint64 allowList, address reserveToken)
        external
        onlyAuthorized
        returns (address)
    {
        NativeAssetIssuer issuer = new NativeAssetIssuer(treasury, aclContract, allowList, reserveToken);
        address issuerAddress = address(issuer);
        isIssuer[issuerAddress] = true;

        emit IssuerCreated(issuerAddress, treasury, reserveToken);

        return issuerAddress;
    }
}
