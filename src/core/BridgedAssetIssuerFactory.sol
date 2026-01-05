// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BridgedAssetIssuer} from "./BridgedAssetIssuer.sol";
import {AbstractContractAuthority} from "./AbstractContractAuthority.sol";

/**
 * @title BridgedAssetIssuerFactory
 * @notice Factory contract for creating BridgedAssetIssuer contracts
 */
contract BridgedAssetIssuerFactory is AbstractContractAuthority {
    event IssuerCreated(address indexed issuer, address indexed treasury, address indexed reserveToken);

    mapping(address => bool) public isIssuer;

    constructor(address aclContract, uint64 allowList) AbstractContractAuthority(aclContract, allowList) {}

    /**
     * @notice Creates a new BridgedAssetIssuer
     * @param treasury The treasury address for the issuer
     * @param aclContract The access control contract address
     * @param allowList The allow list identifier
     * @param reserveToken The reserve token address
     * @return The address of the newly created BridgedAssetIssuer
     */
    function createBridgedAssetIssuer(address treasury, address aclContract, uint64 allowList, address reserveToken)
        external
        onlyAuthorized
        returns (address)
    {
        BridgedAssetIssuer issuer = new BridgedAssetIssuer(treasury, aclContract, allowList, reserveToken);
        address issuerAddress = address(issuer);
        isIssuer[issuerAddress] = true;

        emit IssuerCreated(issuerAddress, treasury, reserveToken);

        return issuerAddress;
    }
}
