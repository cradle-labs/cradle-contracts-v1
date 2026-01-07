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
    echo "Usage: ./scripts/deploy-native-issuer.sh <testnet|mainnet>"
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

# Prompt for missing env vars
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

echo "Deploying NativeAssetIssuer to $NETWORK..."
echo "Treasury: $TREASURY_ADDRESS"
echo "ACL: $ACL_ADDRESS"
echo "Reserve Token: $RESERVE_TOKEN_ADDRESS"
echo "Allow List: $ALLOW_LIST"

forge script script/DeployNativeAssetIssuer.s.sol:DeployNativeAssetIssuer \
    --rpc-url $RPC_URL \
    --broadcast \
    --legacy \
    --slow \
    --gas-estimate-multiplier 200 \
    --via-ir \
    -vvvv
