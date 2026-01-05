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
    echo "Error: .env file not found. Please copy .env.example to .env and fill in your details."
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set in .env"
    exit 1
fi

NETWORK=$1

if [ "$NETWORK" == "testnet" ]; then
    # Allow override from env
    RPC_URL="${HEDERA_TESTNET_RPC:-https://testnet.hashio.io/api}"
    echo "Deploying to Hedera Testnet ($RPC_URL)..."
elif [ "$NETWORK" == "mainnet" ]; then
    RPC_URL="${HEDERA_MAINNET_RPC:-https://mainnet.hashio.io/api}"
    echo "Deploying to Hedera Mainnet ($RPC_URL)..."
else
    echo "Usage: ./deploy.sh [testnet|mainnet]"
    exit 1
fi

echo "Running deployment script..."

# Using --legacy for better compatibility with Hedera
# Using --slow to wait for tx receipts, which helps avoid RPC rate limits/errors
forge script script/Deploy.s.sol:DeployScript \
    --rpc-url $RPC_URL \
    --broadcast \
    --legacy \
    --slow \
    --gas-estimate-multiplier 200 \
    -vvvv
