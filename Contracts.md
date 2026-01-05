# Cradle Protocol Contracts Overview

This document provides a detailed reference for the smart contracts within the `src/core` directory of the Cradle Protocol.

## Core Infrastructure

| Contract | Description |
|----------|-------------|
| **AccessController.sol** | Implements the Role-Based Access Control (RBAC) system. Manages permissions via numeric levels (0=Super Admin). |
| **AbstractContractAuthority.sol** | Abstract base contract that integrates with `AccessController`. Provides the `onlyAuthorized` modifier to restrict function access. |

## Asset Management

| Contract | Description |
|----------|-------------|
| **AbstractCradleAssetManager.sol** | Base contract for all asset managers. Handles HTS token creation, key management, and lifecycle events (mint, burn, wipe). |
| **AssetFactory.sol** | Factory for creating simple `BaseAsset` instances. |
| **BaseAsset.sol** | A basic implementation of a Cradle asset. |
| **NativeAsset.sol** | Represents assets native to the Cradle protocol. |
| **BridgedAsset.sol** | Represents assets bridged from other chains. |
| **NativeAssetIssuer.sol** | Manages the issuance of native assets, including treasury and reserve logic. |
| **BridgedAssetIssuer.sol** | Manages the issuance of bridged assets, handling the minting/burning upon bridge events. |
| **NativeAssetIssuerFactory.sol** | Factory to deploy `NativeAssetIssuer` contracts. |
| **BridgedAssetIssuerFactory.sol** | Factory to deploy `BridgedAssetIssuer` contracts. |
| **AbstractAssetIssuer.sol** | Base contract for asset issuers, defining common logic for reserves and treasury. |
| **AbstractAssetPriceOracle.sol** | Base contract for price oracles, allowing authorized updates to asset prices. |

## Account System

| Contract | Description |
|----------|-------------|
| **CradleAccount.sol** | The "Smart Wallet" of the protocol. Holds assets, manages token associations, handles loan states, and executes transfers. Supports locking assets for collateral. |
| **CradleAccountFactory.sol** | Factory for creating `CradleAccount` instances. Maintains a registry of accounts mapped to controllers and users. |

## Lending & Borrowing

| Contract | Description |
|----------|-------------|
| **AssetLendingPool.sol** | The core lending logic. Manages interest rates, deposits, borrows, repayments, and liquidations. Interacts with `CradleAccount`s for fund movement. |
| **LendingPoolFactory.sol** | Factory to deploy new `AssetLendingPool` instances. |
| **CradleLendingAssetManager.sol** | Specialized asset manager for tokens used within lending pools (e.g., yield-bearing tokens). |
| **AssetLendingPool.sol** | (Note: Logic contained within) Implements the math for variable interest rates and collateralization factors. |

## Trading & Listings

| Contract | Description |
|----------|-------------|
| **CradleOrderBookSettler.sol** | Handles the atomic settlement of matched orders. Transfers assets between buyer and seller accounts and collects fees. |
| **CradleNativeListing.sol** | Manages the initial public offering or listing of a new asset. Allows users to purchase the asset at a fixed price before it hits the order book. |
| **AbstractCradleNativeListing.sol** | Base logic for listings, handling purchase state, limits, and status updates. |
| **CradleListingFactory.sol** | Factory to deploy `CradleNativeListing` contracts. |

## Interfaces & Utilities

- **Hedera Integration**: The contracts heavily utilize `HederaTokenService` and `IHederaTokenService` system contracts for low-level token operations.
- **OpenZeppelin**: Uses `ReentrancyGuard` and `IERC20` interfaces for standard compliance and security.
