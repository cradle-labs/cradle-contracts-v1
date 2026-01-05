#!/usr/bin/env bash

# Batch Hedera Contract Verification Script
# This script allows you to verify multiple contracts in one session

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
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-contract.sh"

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Batch Hedera Contract Verification Script            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if verify-contract.sh exists
if [ ! -f "$VERIFY_SCRIPT" ]; then
    echo -e "${RED}Error: verify-contract.sh not found at $VERIFY_SCRIPT${NC}"
    exit 1
fi

# Arrays to store verification data
declare -a CONTRACTS_TO_VERIFY
declare -a ADDRESSES
declare -a CONSTRUCTOR_ARGS

# Function to add contract to verification queue
add_contract() {
    echo -e "${BLUE}Available Contracts:${NC}"
    echo "  1.  AccessController"
    echo "  2.  AssetFactory"
    echo "  3.  AssetLendingPool"
    echo "  4.  BaseAsset"
    echo "  5.  BridgedAsset"
    echo "  6.  BridgedAssetIssuer"
    echo "  7.  CradleAccount"
    echo "  8.  CradleAccountFactory"
    echo "  9.  CradleLendingAssetManager"
    echo "  10. CradleListingFactory"
    echo "  11. CradleNativeListing"
    echo "  12. CradleOrderBookSettler"
    echo "  13. LendingPoolFactory"
    echo "  14. NativeAsset"
    echo "  15. NativeAssetIssuer"
    echo ""
    
    read -p "Select contract (1-15) or name: " contract_input
    
    case $contract_input in
        1) contract_name="AccessController" ;;
        2) contract_name="AssetFactory" ;;
        3) contract_name="AssetLendingPool" ;;
        4) contract_name="BaseAsset" ;;
        5) contract_name="BridgedAsset" ;;
        6) contract_name="BridgedAssetIssuer" ;;
        7) contract_name="CradleAccount" ;;
        8) contract_name="CradleAccountFactory" ;;
        9) contract_name="CradleLendingAssetManager" ;;
        10) contract_name="CradleListingFactory" ;;
        11) contract_name="CradleNativeListing" ;;
        12) contract_name="CradleOrderBookSettler" ;;
        13) contract_name="LendingPoolFactory" ;;
        14) contract_name="NativeAsset" ;;
        15) contract_name="NativeAssetIssuer" ;;
        *) contract_name="$contract_input" ;;
    esac
    
    read -p "Contract address: " address
    
    echo ""
    echo -e "${YELLOW}Constructor Arguments Info:${NC}"
    case $contract_name in
        "AccessController")
            echo "  No constructor arguments needed"
            args=""
            ;;
        "AssetFactory"|"CradleAccountFactory"|"CradleListingFactory"|"LendingPoolFactory")
            echo "  Required: aclContract (address)"
            read -p "ACL Contract Address: " args
            ;;
        "BaseAsset"|"BridgedAsset"|"NativeAsset"|"CradleLendingAssetManager")
            echo "  Required: name (string), symbol (string), aclContract (address), allowList (uint64)"
            read -p "Token Name: " name
            read -p "Token Symbol: " symbol
            read -p "ACL Contract: " acl
            read -p "Allow List Level: " level
            args="\"$name\" \"$symbol\" $acl $level"
            ;;
        "BridgedAssetIssuer"|"NativeAssetIssuer")
            echo "  Required: aclContract (address), treasury (address), reserveToken (address)"
            read -p "ACL Contract: " acl
            read -p "Treasury Address: " treasury
            read -p "Reserve Token: " reserve
            args="$acl $treasury $reserve"
            ;;
        "CradleAccount")
            echo "  Required: controller (string), aclContract (address), allowList (uint64)"
            read -p "Controller ID: " controller
            read -p "ACL Contract: " acl
            read -p "Allow List Level: " level
            args="\"$controller\" $acl $level"
            ;;
        "CradleOrderBookSettler")
            echo "  Required: aclContract (address), treasury (address)"
            read -p "ACL Contract: " acl
            read -p "Treasury Address: " treasury
            args="$acl $treasury"
            ;;
        "CradleNativeListing")
            echo "  Required: feeCollector, reserve, maxSupply, asset, purchaseAsset, purchasePrice, beneficiary, shadowAsset"
            read -p "Fee Collector: " fee
            read -p "Reserve: " reserve
            read -p "Max Supply: " max
            read -p "Asset: " asset
            read -p "Purchase Asset: " purchase
            read -p "Purchase Price: " price
            read -p "Beneficiary: " beneficiary
            read -p "Shadow Asset: " shadow
            args="$fee $reserve $max $asset $purchase $price $beneficiary $shadow"
            ;;
        "AssetLendingPool")
            echo "  Required: aclContract, yieldBearingAsset, lendingAsset, ltv, liquidationThreshold, liquidationDiscount, baseRate, slope1, slope2, optimalUtilization"
            read -p "ACL Contract: " acl
            read -p "Yield Bearing Asset: " yield
            read -p "Lending Asset: " lending
            read -p "LTV (e.g., 7000): " ltv
            read -p "Liquidation Threshold (e.g., 8000): " liqThresh
            read -p "Liquidation Discount (e.g., 500): " liqDisc
            read -p "Base Rate (e.g., 100000000000000000): " base
            read -p "Slope1 (e.g., 200000000000000000): " slope1
            read -p "Slope2 (e.g., 9500): " slope2
            read -p "Optimal Utilization (e.g., 8000): " optimal
            args="$acl $yield $lending $ltv $liqThresh $liqDisc $base $slope1 $slope2 $optimal"
            ;;
        *)
            echo "  Enter constructor arguments (space-separated):"
            read -p "Arguments: " args
            ;;
    esac
    
    CONTRACTS_TO_VERIFY+=("$contract_name")
    ADDRESSES+=("$address")
    CONSTRUCTOR_ARGS+=("$args")
    
    echo -e "${GREEN}✓ Added $contract_name to verification queue${NC}"
    echo ""
}

# Main menu
while true; do
    echo -e "${YELLOW}Current Queue (${#CONTRACTS_TO_VERIFY[@]} contracts):${NC}"
    if [ ${#CONTRACTS_TO_VERIFY[@]} -eq 0 ]; then
        echo "  (empty)"
    else
        for i in "${!CONTRACTS_TO_VERIFY[@]}"; do
            echo "  $((i+1)). ${CONTRACTS_TO_VERIFY[$i]} at ${ADDRESSES[$i]}"
        done
    fi
    echo ""
    
    echo "Options:"
    echo "  1. Add contract to verification queue"
    echo "  2. Remove contract from queue"
    echo "  3. Start batch verification"
    echo "  4. Clear queue"
    echo "  5. Exit"
    echo ""
    
    read -p "Select option (1-5): " option
    echo ""
    
    case $option in
        1)
            add_contract
            ;;
        2)
            if [ ${#CONTRACTS_TO_VERIFY[@]} -eq 0 ]; then
                echo -e "${RED}Queue is empty${NC}"
                echo ""
            else
                read -p "Enter index to remove (1-${#CONTRACTS_TO_VERIFY[@]}): " idx
                idx=$((idx-1))
                if [ $idx -ge 0 ] && [ $idx -lt ${#CONTRACTS_TO_VERIFY[@]} ]; then
                    removed="${CONTRACTS_TO_VERIFY[$idx]}"
                    unset 'CONTRACTS_TO_VERIFY[$idx]'
                    unset 'ADDRESSES[$idx]'
                    unset 'CONSTRUCTOR_ARGS[$idx]'
                    CONTRACTS_TO_VERIFY=("${CONTRACTS_TO_VERIFY[@]}")
                    ADDRESSES=("${ADDRESSES[@]}")
                    CONSTRUCTOR_ARGS=("${CONSTRUCTOR_ARGS[@]}")
                    echo -e "${GREEN}✓ Removed $removed${NC}"
                else
                    echo -e "${RED}Invalid index${NC}"
                fi
                echo ""
            fi
            ;;
        3)
            if [ ${#CONTRACTS_TO_VERIFY[@]} -eq 0 ]; then
                echo -e "${RED}Queue is empty. Add contracts first.${NC}"
                echo ""
            else
                echo -e "${GREEN}Starting verification of ${#CONTRACTS_TO_VERIFY[@]} contracts...${NC}"
                echo ""
                
                success_count=0
                fail_count=0
                
                for i in "${!CONTRACTS_TO_VERIFY[@]}"; do
                    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    echo -e "${BLUE}Verifying ($((i+1))/${#CONTRACTS_TO_VERIFY[@]}): ${CONTRACTS_TO_VERIFY[$i]}${NC}"
                    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
                    
                    if bash "$VERIFY_SCRIPT" "${CONTRACTS_TO_VERIFY[$i]}" "${ADDRESSES[$i]}" ${CONSTRUCTOR_ARGS[$i]}; then
                        ((success_count++))
                    else
                        ((fail_count++))
                        echo -e "${RED}Failed to verify ${CONTRACTS_TO_VERIFY[$i]}${NC}"
                    fi
                    echo ""
                done
                
                echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${GREEN}║              Batch Verification Complete                   ║${NC}"
                echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
                echo -e "${GREEN}Successful: $success_count${NC}"
                echo -e "${RED}Failed: $fail_count${NC}"
                echo ""
                
                # Clear queue after verification
                CONTRACTS_TO_VERIFY=()
                ADDRESSES=()
                CONSTRUCTOR_ARGS=()
            fi
            ;;
        4)
            CONTRACTS_TO_VERIFY=()
            ADDRESSES=()
            CONSTRUCTOR_ARGS=()
            echo -e "${GREEN}✓ Queue cleared${NC}"
            echo ""
            ;;
        5)
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option${NC}"
            echo ""
            ;;
    esac
done
