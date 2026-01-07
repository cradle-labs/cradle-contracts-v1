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

NETWORK=$1

if [ -z "$NETWORK" ]; then
    echo "Usage: ./scripts/interact-native-issuer.sh <testnet|mainnet>"
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

# Prompt for interaction details
if [ -z "$ISSUER_ADDRESS" ]; then
    read -p "Enter Native Asset Issuer Address: " ISSUER_ADDRESS
    export ISSUER_ADDRESS
fi

read -p "Enter Asset Name: " ASSET_NAME
export ASSET_NAME

read -p "Enter Asset Symbol: " ASSET_SYMBOL
export ASSET_SYMBOL

if [ -z "$ACL_ADDRESS" ]; then
    read -p "Enter AccessController Address for the new asset: " ACL_ADDRESS
    export ACL_ADDRESS
fi

read -p "Enter Allow List Level for the new asset (default: 1): " INPUT_ALLOW_LIST
export ALLOW_LIST=${INPUT_ALLOW_LIST:-1}

echo "Interacting with NativeAssetIssuer at $ISSUER_ADDRESS on $NETWORK..."
echo "Creating Asset: $ASSET_NAME ($ASSET_SYMBOL)"

forge script script/InteractNativeAssetIssuer.s.sol:InteractNativeAssetIssuer \
    --rpc-url $RPC_URL \
    --skip-simulation \
    --broadcast \
    --legacy \
    --slow \
    --gas-estimate-multiplier 200 \
    --via-ir \
    -vvvv
