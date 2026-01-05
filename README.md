# Cradle Protocol Contracts

Smart contracts for the Cradle Protocol, a comprehensive DeFi suite on the Hedera network facilitating asset issuance, lending, and orderbook trading.

## Documentation

- [Architecture Overview](./Architecture.md) - Detailed system architecture and diagrams.
- [Security Model](./SecurityModel.md) - Access control and security patterns.
- [Contracts Reference](./Contracts.md) - Detailed description of all contracts.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- A Hedera Testnet Account (ECDSA key preferred for EVM compatibility)

## Setup

1. **Install Dependencies**
   ```bash
   forge install
   ```

2. **Environment Configuration**
   Copy the example environment file and fill in your details:
   ```bash
   cp .env.example .env
   ```
   Required variables:
   - `PRIVATE_KEY`: Your Hedera account private key (ECDSA).
   - `HEDERA_TESTNET_RPC`: RPC URL (e.g., `https://testnet.hashio.io/api`).

## Development

### Build
```bash
forge build
```

### Test
Run the full test suite:
```bash
forge test
```

### Deployment
Use the provided shell script to deploy to the Hedera Testnet. This script handles the `forge script` execution with appropriate flags for Hedera.

```bash
./deploy.sh testnet
```

### Verification
Verify deployed contracts on Sourcify/HashScan using the verification script:

```bash
./scripts/verify-contract.sh <ContractName> <Address> [ConstructorArgs]
```

## Project Structure & Functionality

| Directory/File | Functionality |
|----------------|---------------|
| `src/core/` | **Core Smart Contracts** |
| `src/core/AccessController.sol` | Role-Based Access Control (RBAC) system. |
| `src/core/CradleAccount.sol` | Smart wallet/vault for users and protocol entities. |
| `src/core/AssetLendingPool.sol` | Lending and borrowing logic. |
| `src/core/CradleOrderBookSettler.sol` | Atomic settlement for off-chain orderbook matches. |
| `src/core/AssetFactory.sol` | Factory for creating standard assets. |
| `script/Deploy.s.sol` | **Deployment Scripts** |
| `script/Deploy.s.sol` | Main Solidity script for orchestrating deployment. |
| `scripts/` | **Utility Scripts** |
| `deploy.sh` | Bash wrapper for deployment. |
| `verify-contract.sh` | Tool for verifying contracts on Hedera explorers. |
| `test/` | **Tests** |
| `test/*.t.sol` | Foundry test files (Unit and Integration tests). |

## Key Features

- **Native Hedera Token Service (HTS)**: Assets are native HTS tokens managed by smart contracts.
- **Granular Access Control**: Multi-level permission system for secure operations.
- **Isolated Accounts**: Each user has a dedicated smart contract account for enhanced security and logic.
- **Atomic Settlement**: Orderbook trades are settled atomically on-chain.
