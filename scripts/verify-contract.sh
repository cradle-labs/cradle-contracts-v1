#!/usr/bin/env bash

# Hedera Contract Verification Script
# Usage: ./scripts/verify-contract.sh <contract_name> <contract_address> [constructor_args]
# Example: ./scripts/verify-contract.sh AccessController 0x1234... ""
# Example: ./scripts/verify-contract.sh AssetFactory 0x5678... "0xACLAddress"

set -e

# Check if running in bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script requires bash"
    echo "Please run with: bash $0 $@"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Hedera network configuration
CHAIN_ID=296  # Hedera Testnet
VERIFIER="sourcify"
VERIFIER_URL="https://server-verify.hashscan.io"

# Function to get contract path
get_contract_path() {
    case "$1" in
        "AccessController") echo "src/core/AccessController.sol:AccessController" ;;
        "AssetFactory") echo "src/core/AssetFactory.sol:AssetFactory" ;;
        "AssetLendingPool") echo "src/core/AssetLendingPool.sol:AssetLendingPool" ;;
        "BaseAsset") echo "src/core/BaseAsset.sol:BaseAsset" ;;
        "BridgedAsset") echo "src/core/BridgedAsset.sol:BridgedAsset" ;;
        "BridgedAssetIssuer") echo "src/core/BridgedAssetIssuer.sol:BridgedAssetIssuer" ;;
        "BridgedAssetIssuerFactory") echo "src/core/BridgedAssetIssuerFactory.sol:BridgedAssetIssuerFactory" ;;
        "CradleAccount") echo "src/core/CradleAccount.sol:CradleAccount" ;;
        "CradleAccountFactory") echo "src/core/CradleAccountFactory.sol:CradleAccountFactory" ;;
        "CradleLendingAssetManager") echo "src/core/CradleLendingAssetManager.sol:CradleLendingAssetManager" ;;
        "CradleListingFactory") echo "src/core/CradleListingFactory.sol:CradleListingFactory" ;;
        "CradleNativeListing") echo "src/core/CradleNativeListing.sol:CradleNativeListing" ;;
        "CradleOrderBookSettler") echo "src/core/CradleOrderBookSettler.sol:CradleOrderBookSettler" ;;
        "LendingPoolFactory") echo "src/core/LendingPoolFactory.sol:LendingPoolFactory" ;;
        "NativeAsset") echo "src/core/NativeAsset.sol:NativeAsset" ;;
        "NativeAssetIssuer") echo "src/core/NativeAssetIssuer.sol:NativeAssetIssuer" ;;
        "NativeAssetIssuerFactory") echo "src/core/NativeAssetIssuerFactory.sol:NativeAssetIssuerFactory" ;;
        *) echo "" ;;
    esac
}

# Function to get constructor signature
get_constructor_sig() {
    case "$1" in
        "AccessController") echo "" ;;
        "AssetFactory") echo "constructor(address)" ;;
        "AssetLendingPool") echo "constructor(address,address,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256)" ;;
        "BaseAsset") echo "constructor(string,string,address,uint64)" ;;
        "BridgedAsset") echo "constructor(string,string,address,uint64)" ;;
        "BridgedAssetIssuer") echo "constructor(address,address,address)" ;;
        "BridgedAssetIssuerFactory") echo "constructor(address,uint64)" ;;
        "CradleAccount") echo "constructor(string,address,uint64)" ;;
        "CradleAccountFactory") echo "constructor(address,uint64)" ;;
        "CradleLendingAssetManager") echo "constructor(string,string,address,uint64)" ;;
        "CradleListingFactory") echo "constructor(address)" ;;
        "CradleNativeListing") echo "constructor(address,address,uint256,address,address,uint256,address,address)" ;;
        "CradleOrderBookSettler") echo "constructor(address,address)" ;;
        "LendingPoolFactory") echo "constructor(address)" ;;
        "NativeAsset") echo "constructor(string,string,address,uint64)" ;;
        "NativeAssetIssuer") echo "constructor(address,address,address)" ;;
        "NativeAssetIssuerFactory") echo "constructor(address,uint64)" ;;
        *) echo "" ;;
    esac
}

# Help function
show_help() {
    echo -e "${GREEN}Hedera Contract Verification Script${NC}"
    echo ""
    echo "Usage: $0 <contract_name> <contract_address> [constructor_args_json]"
    echo ""
    echo "Arguments:"
    echo "  contract_name        Name of the contract to verify"
    echo "  contract_address     Deployed contract address on Hedera"
    echo "  constructor_args_json Constructor arguments in JSON format (optional)"
    echo ""
    echo "Available Contracts:"
    echo "  - AccessController"
    echo "  - AssetFactory"
    echo "  - AssetLendingPool"
    echo "  - BaseAsset"
    echo "  - BridgedAsset"
    echo "  - BridgedAssetIssuer"
    echo "  - CradleAccount"
    echo "  - CradleAccountFactory"
    echo "  - CradleLendingAssetManager"
    echo "  - CradleListingFactory"
    echo "  - CradleNativeListing"
    echo "  - CradleOrderBookSettler"
    echo "  - LendingPoolFactory"
    echo "  - NativeAsset"
    echo "  - NativeAssetIssuer"
    echo ""
    echo "Examples:"
    echo "  # No constructor args"
    echo "  $0 AccessController 0x1234567890abcdef1234567890abcdef12345678"
    echo ""
    echo "  # Single address argument"
    echo "  $0 AssetFactory 0x1234567890abcdef1234567890abcdef12345678 '0xACLAddress123'"
    echo ""
    echo "  # Multiple arguments (space-separated)"
    echo "  $0 CradleAccount 0x1234567890abcdef1234567890abcdef12345678 'controller_id 0xACLAddr 1'"
    echo ""
    echo "  # Complex constructor (10 args for AssetLendingPool)"
    echo "  $0 AssetLendingPool 0x1234567890abcdef1234567890abcdef12345678 '0xACL 0xAsset 0xYield 7000 1000 500 100000000000000000 200000000000000000 8000 9500'"
    echo ""
    echo "Constructor Signatures:"
    for contract in AccessController AssetFactory AssetLendingPool BaseAsset BridgedAsset BridgedAssetIssuer CradleAccount CradleAccountFactory CradleLendingAssetManager CradleListingFactory CradleNativeListing CradleOrderBookSettler LendingPoolFactory NativeAsset NativeAssetIssuer; do
        sig=$(get_constructor_sig "$contract")
        if [ -z "$sig" ]; then
            echo "  $contract: No constructor arguments"
        else
            echo "  $contract: $sig"
        fi
    done
}

# Check arguments
if [ "$#" -lt 2 ]; then
    echo -e "${RED}Error: Insufficient arguments${NC}"
    echo ""
    show_help
    exit 1
fi

CONTRACT_NAME=$1
CONTRACT_ADDRESS=$2
CONSTRUCTOR_ARGS_RAW="${@:3}"  # All remaining arguments

# Validate contract name
CONTRACT_PATH=$(get_contract_path "$CONTRACT_NAME")
if [ -z "$CONTRACT_PATH" ]; then
    echo -e "${RED}Error: Unknown contract '$CONTRACT_NAME'${NC}"
    echo ""
    echo "Available contracts:"
    echo "  - AccessController"
    echo "  - AssetFactory"
    echo "  - AssetLendingPool"
    echo "  - BaseAsset"
    echo "  - BridgedAsset"
    echo "  - BridgedAssetIssuer"
    echo "  - CradleAccount"
    echo "  - CradleAccountFactory"
    echo "  - CradleLendingAssetManager"
    echo "  - CradleListingFactory"
    echo "  - CradleNativeListing"
    echo "  - CradleOrderBookSettler"
    echo "  - LendingPoolFactory"
    echo "  - NativeAsset"
    echo "  - NativeAssetIssuer"
    exit 1
fi

CONSTRUCTOR_SIG=$(get_constructor_sig "$CONTRACT_NAME")

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Hedera Contract Verification Script               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Contract:${NC}        $CONTRACT_NAME"
echo -e "${YELLOW}Source:${NC}          $CONTRACT_PATH"
echo -e "${YELLOW}Address:${NC}         $CONTRACT_ADDRESS"
echo -e "${YELLOW}Chain ID:${NC}        $CHAIN_ID (Hedera Testnet)"
echo -e "${YELLOW}Verifier:${NC}        $VERIFIER"
echo -e "${YELLOW}Verifier URL:${NC}    $VERIFIER_URL"

# Build constructor args if provided
if [ -n "$CONSTRUCTOR_SIG" ] && [ -n "$CONSTRUCTOR_ARGS_RAW" ]; then
    echo -e "${YELLOW}Constructor Sig:${NC} $CONSTRUCTOR_SIG"
    echo -e "${YELLOW}Constructor Args:${NC} $CONSTRUCTOR_ARGS_RAW"
    
    # Encode constructor arguments
    ENCODED_ARGS=$(cast abi-encode "$CONSTRUCTOR_SIG" $CONSTRUCTOR_ARGS_RAW)
    
    echo -e "${YELLOW}Encoded Args:${NC}    $ENCODED_ARGS"
    echo ""
    
    # Verify with constructor args
    echo -e "${GREEN}Verifying contract with constructor arguments...${NC}"
    forge verify-contract "$CONTRACT_ADDRESS" "$CONTRACT_PATH" \
        --chain-id "$CHAIN_ID" \
        --verifier "$VERIFIER" \
        --verifier-url "$VERIFIER_URL" \
        --constructor-args "$ENCODED_ARGS" \
        --watch
        
elif [ -n "$CONSTRUCTOR_SIG" ] && [ -z "$CONSTRUCTOR_ARGS_RAW" ]; then
    echo -e "${YELLOW}Constructor Sig:${NC} $CONSTRUCTOR_SIG"
    echo -e "${RED}Warning: This contract requires constructor arguments but none were provided${NC}"
    echo -e "${RED}Expected signature: $CONSTRUCTOR_SIG${NC}"
    echo ""
    read -p "Continue without constructor args? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Verification cancelled${NC}"
        exit 1
    fi
    
    # Verify without constructor args
    echo -e "${GREEN}Verifying contract...${NC}"
    forge verify-contract "$CONTRACT_ADDRESS" "$CONTRACT_PATH" \
        --chain-id "$CHAIN_ID" \
        --verifier "$VERIFIER" \
        --verifier-url "$VERIFIER_URL" \
        --watch
        
else
    echo -e "${YELLOW}Constructor:${NC}     None"
    echo ""
    
    # Verify without constructor args
    echo -e "${GREEN}Verifying contract...${NC}"
    forge verify-contract "$CONTRACT_ADDRESS" "$CONTRACT_PATH" \
        --chain-id "$CHAIN_ID" \
        --verifier "$VERIFIER" \
        --verifier-url "$VERIFIER_URL" \
        --watch
fi

# Check verification result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Contract verified successfully!${NC}"
    echo -e "${GREEN}  View on HashScan: https://hashscan.io/testnet/contract/$CONTRACT_ADDRESS${NC}"
else
    echo ""
    echo -e "${RED}✗ Verification failed${NC}"
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Ensure the contract address is correct"
    echo "  2. Verify constructor arguments match deployment"
    echo "  3. Check that the contract was compiled with the same settings"
    echo "  4. Wait a few moments and try again (network delay)"
    exit 1
fi
