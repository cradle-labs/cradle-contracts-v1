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

CONTRACT_NAME=$1
NETWORK=$2

if [ -z "$CONTRACT_NAME" ] || [ -z "$NETWORK" ]; then
    echo "Usage: ./scripts/deploy-specific.sh <ContractName> <testnet|mainnet>"
    echo "Available Contracts: AccessController, CradleOrderBookSettler, AssetFactory, NativeAssetIssuerFactory, BridgedAssetIssuerFactory, CradleAccountFactory, CradleListingFactory, LendingPoolFactory"
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

echo "Deploying $CONTRACT_NAME to $NETWORK..."

# Requirements check per contract
if [ "$CONTRACT_NAME" != "AccessController" ] && [ -z "$ACL_ADDRESS" ]; then
    read -p "Enter AccessController Address (ACL_ADDRESS): " ACL_ADDRESS
    export ACL_ADDRESS
fi

if [ "$CONTRACT_NAME" == "CradleOrderBookSettler" ] && [ -z "$TREASURY_ADDRESS" ]; then
    read -p "Enter Treasury Address (TREASURY_ADDRESS): " TREASURY_ADDRESS
    export TREASURY_ADDRESS
fi

if [[ "$CONTRACT_NAME" == *"IssuerFactory" ]] || [ "$CONTRACT_NAME" == "CradleAccountFactory" ]; then
    if [ -z "$ALLOW_LIST" ]; then
        read -p "Enter Allow List Level (ALLOW_LIST): " ALLOW_LIST
        export ALLOW_LIST
    fi
fi

export CONTRACT_NAME

forge script script/DeploySpecific.s.sol:DeploySpecific \
    --rpc-url $RPC_URL \
    --broadcast \
    --legacy \
    --slow \
    --gas-estimate-multiplier 200 \
    --via-ir \
    -vvvv
