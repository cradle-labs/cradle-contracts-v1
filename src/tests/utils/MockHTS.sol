// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {HederaResponseCodes} from "@hedera/HederaResponseCodes.sol";
import {IHederaTokenService} from "@hedera/hedera-token-service/IHederaTokenService.sol";

/**
 * @title MockHTS
 * @notice Mock Hedera Token Service for testing
 * @dev This contract simulates the HTS precompile at address 0x167
 */
contract MockHTS {
    uint256 private tokenCounter;

    function createFungibleToken(IHederaTokenService.HederaToken memory, uint256, uint256)
        external
        payable
        returns (int256 responseCode, address tokenAddress)
    {
        tokenCounter++;
        tokenAddress = address(uint160(uint256(keccak256(abi.encodePacked(tokenCounter, block.timestamp, msg.sender)))));
        responseCode = HederaResponseCodes.SUCCESS;
    }

    function mintToken(address, int64, bytes[] memory)
        external
        returns (int64 responseCode, int64 newTotalSupply, int64[] memory serialNumbers)
    {
        responseCode = int64(int256(HederaResponseCodes.SUCCESS));
        newTotalSupply = 0;
        serialNumbers = new int64[](0);
        return (responseCode, newTotalSupply, serialNumbers);
    }

    function burnToken(address, int64, int64[] memory) external returns (int64 responseCode, int64 newTotalSupply) {
        responseCode = int64(int256(HederaResponseCodes.SUCCESS));
        newTotalSupply = 0;
        return (responseCode, newTotalSupply);
    }

    function associateToken(address, address) external returns (int256 responseCode) {
        responseCode = HederaResponseCodes.SUCCESS;
    }

    // Fallback to handle any other calls
    fallback() external payable {
        assembly {
            mstore(0x00, 22) // SUCCESS code
            mstore(0x20, caller()) // Return caller as token address
            return(0x00, 0x40)
        }
    }
}
