#!/bin/bash

# Generic Asset Issuer Script (Native & Bridged)
# Usage: ./scripts/asset-issuer.sh <native|bridged> <deploy|interact> <testnet|mainnet>

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

ISSUER_TYPE=$1
ACTION=$2
NETWORK=$3

if [ -z "$ISSUER_TYPE" ] || [ -z "$ACTION" ] || [ -z "$NETWORK" ]; then
    echo "Usage: ./scripts/asset-issuer.sh <native|bridged> <deploy|interact> <testnet|mainnet>"
    exit 1
fi

if [ "$ISSUER_TYPE" != "native" ] && [ "$ISSUER_TYPE" != "bridged" ]; then
    echo "Error: Invalid issuer type. Use 'native' or 'bridged'."
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

# Common input helpers
setup_deploy_vars() {
    if [ -z "$TREASURY_ADDRESS" ]; then
        read -p "Enter Treasury Address: " TREASURY_ADDRESS
        export TREASURY_ADDRESS
    fi
    if [ -z "$ACL_ADDRESS" ]; then
        read -p "Enter AccessController Address: " ACL_ADDRESS
        export ACL_ADDRESS
    fi
    if [ -z "$RESERVE_TOKEN_ADDRESS" ]; then
        read -p "Enter Reserve Token Address: " RESERVE_TOKEN_ADDRESS
        export RESERVE_TOKEN_ADDRESS
    fi
    if [ -z "$ALLOW_LIST" ]; then
        read -p "Enter Allow List Level (default: 1): " INPUT_ALLOW_LIST
        export ALLOW_LIST=${INPUT_ALLOW_LIST:-1}
    fi
}

setup_interact_vars() {
    if [ -z "$ISSUER_ADDRESS" ]; then
        read -p "Enter ${ISSUER_TYPE^} Asset Issuer Address: " ISSUER_ADDRESS
        export ISSUER_ADDRESS
    fi
    
    read -p "Enter New Asset Name: " ASSET_NAME
    export ASSET_NAME

    read -p "Enter New Asset Symbol: " ASSET_SYMBOL
    export ASSET_SYMBOL
    
    if [ -z "$ACL_ADDRESS" ]; then
        read -p "Enter AccessController Address for the new asset: " ACL_ADDRESS
        export ACL_ADDRESS
    fi
    
    if [ -z "$ALLOW_LIST" ]; then
        read -p "Enter Allow List Level (default: 1): " INPUT_ALLOW_LIST
        export ALLOW_LIST=${INPUT_ALLOW_LIST:-1}
    fi
}

# --- Execution ---

if [ "$ACTION" == "deploy" ]; then
    echo "=== Deploying $ISSUER_TYPE Asset Issuer to $NETWORK ==="
    setup_deploy_vars
    
    if [ "$ISSUER_TYPE" == "native" ]; then
        SCRIPT="script/DeployNativeAssetIssuer.s.sol:DeployNativeAssetIssuer"
    else
        SCRIPT="script/DeployBridgedAssetIssuer.s.sol:DeployBridgedAssetIssuer"
    fi

elif [ "$ACTION" == "interact" ]; then
    echo "=== Interacting with $ISSUER_TYPE Asset Issuer on $NETWORK ==="
    setup_interact_vars
    
    if [ "$ISSUER_TYPE" == "native" ]; then
        SCRIPT="script/InteractNativeAssetIssuer.s.sol:InteractNativeAssetIssuer"
    else
        SCRIPT="script/InteractBridgedAssetIssuer.s.sol:InteractBridgedAssetIssuer"
    fi

else
    echo "Error: Invalid action. Use 'deploy' or 'interact'."
    exit 1
fi

# Run Forge
forge script $SCRIPT \
    --ffi \
    --rpc-url $RPC_URL \
    --broadcast \
    --legacy \
    --slow \
    --gas-estimate-multiplier 200 \
    --via-ir \
    -vvvv
