#!/bin/bash

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo "Error: forge is not installed. Please install Foundry."
    exit 1
fi

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found."
    exit 1
fi

ACTION=$1
NETWORK=$2

if [ -z "$ACTION" ] || [ -z "$NETWORK" ]; then
    echo "Usage: ./scripts/bridged-issuer.sh <deploy|interact> <testnet|mainnet>"
    exit 1
fi

if [ "$NETWORK" == "testnet" ]; then
    RPC_URL="${HEDERA_TESTNET_RPC:-https://testnet.hashio.io/api}"
elif [ "$NETWORK" == "mainnet" ]; then
    RPC_URL="${HEDERA_MAINNET_RPC:-https://mainnet.hashio.io/api}"
else
    echo "Error: Invalid network. Use 'testnet' or 'mainnet'."
    exit 1
fi

# Common variables setup
setup_common_vars() {
    if [ -z "$ACL_ADDRESS" ]; then
        read -p "Enter AccessController Address: " ACL_ADDRESS
        export ACL_ADDRESS
    fi
    if [ -z "$ALLOW_LIST" ]; then
        read -p "Enter Allow List Level (default: 1): " INPUT_ALLOW_LIST
        export ALLOW_LIST=${INPUT_ALLOW_LIST:-1}
    fi
}

if [ "$ACTION" == "deploy" ]; then
    echo "=== Deploying BridgedAssetIssuer to $NETWORK ==="
    
    if [ -z "$TREASURY_ADDRESS" ]; then
        read -p "Enter Treasury Address: " TREASURY_ADDRESS
        export TREASURY_ADDRESS
    fi
    
    setup_common_vars
    
    if [ -z "$RESERVE_TOKEN_ADDRESS" ]; then
        read -p "Enter Reserve Token Address: " RESERVE_TOKEN_ADDRESS
        export RESERVE_TOKEN_ADDRESS
    fi

    forge script script/DeployBridgedAssetIssuer.s.sol:DeployBridgedAssetIssuer \
        --rpc-url $RPC_URL \
        --broadcast \
        --legacy \
        --slow \
        --gas-estimate-multiplier 200 \
        --via-ir \
        -vvvv

elif [ "$ACTION" == "interact" ]; then
    echo "=== Interacting with BridgedAssetIssuer on $NETWORK ==="
    
    if [ -z "$ISSUER_ADDRESS" ]; then
        read -p "Enter Bridged Asset Issuer Address: " ISSUER_ADDRESS
        export ISSUER_ADDRESS
    fi
    
    read -p "Enter New Asset Name: " ASSET_NAME
    export ASSET_NAME

    read -p "Enter New Asset Symbol: " ASSET_SYMBOL
    export ASSET_SYMBOL
    
    setup_common_vars

    forge script script/InteractBridgedAssetIssuer.s.sol:InteractBridgedAssetIssuer \
        --rpc-url $RPC_URL \
        --broadcast \
        --legacy \
        --slow \
        --ffi \
        --gas-estimate-multiplier 200 \
        --via-ir \
        -vvvv


else
    echo "Error: Invalid action. Use 'deploy' or 'interact'."
    exit 1
fi
