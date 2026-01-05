# Cradle Protocol Architecture

The Cradle Protocol is a comprehensive suite of smart contracts on the Hedera network designed to facilitate asset issuance, management, lending, and trading. The architecture is modular, centering around a robust access control system and specialized factories for scalability.

## High-Level Architecture

The system is composed of several key subsystems:
1.  **Core Infrastructure**: Access control and base authorities.
2.  **Asset Management**: Issuance and management of HTS tokens (Native and Bridged).
3.  **Account System**: Smart accounts (`CradleAccount`) for holding assets and managing user interactions.
4.  **DeFi Primitives**: Lending pools and Orderbook settlement.

```mermaid
graph TD
    subgraph Core [Core Infrastructure]
        ACL[AccessController]
        Auth[AbstractContractAuthority]
    end

    subgraph Assets [Asset Management]
        AF[AssetFactory]
        NAF[NativeAssetIssuerFactory]
        BAF[BridgedAssetIssuerFactory]
        AM[AbstractCradleAssetManager]
        NA[NativeAsset]
        BA[BridgedAsset]
    end

    subgraph Accounts [Account System]
        CAF[CradleAccountFactory]
        CA[CradleAccount]
    end

    subgraph DeFi [DeFi Services]
        LPF[LendingPoolFactory]
        ALP[AssetLendingPool]
        OBS[CradleOrderBookSettler]
        CLF[CradleListingFactory]
        CNL[CradleNativeListing]
    end

    ACL --> Auth
    Auth --> AF
    Auth --> CAF
    Auth --> LPF
    Auth --> OBS
    
    AF --> AM
    NAF --> NA
    BAF --> BA
    
    CAF --> CA
    
    LPF --> ALP
    CLF --> CNL
    
    ALP -- Uses for Reserve/Treasury --> CA
    OBS -- Settles trades between accounts --> CA
```

## Component Interactions

### 1. Asset Issuance & Management
Assets in Cradle are wrappers or managers around Hedera Token Service (HTS) tokens.
- **Issuers**: `NativeAssetIssuer` and `BridgedAssetIssuer` handle the logic for creating new assets.
- **Managers**: `NativeAsset` and `BridgedAsset` (inheriting `AbstractCradleAssetManager`) hold the HTS keys and manage supply (mint/burn).

```mermaid
sequenceDiagram
    participant Admin
    participant IssuerFactory
    participant Issuer
    participant AssetManager
    participant HTS as Hedera Token Service

    Admin->>IssuerFactory: createIssuer()
    IssuerFactory->>Issuer: deploy new()
    
    Admin->>Issuer: createAsset(name, symbol)
    Issuer->>AssetManager: deploy new()
    AssetManager->>HTS: createFungibleToken()
    HTS-->>AssetManager: tokenAddress
    AssetManager-->>Issuer: assetAddress
```

### 2. Cradle Accounts
`CradleAccount` serves as the primary identity and vault for users and protocols.
- It holds balances.
- It manages collateral for lending.
- It executes transfers for trading.

```mermaid
classDiagram
    class CradleAccount {
        +string controller
        +mapping loans
        +mapping loanCollaterals
        +deposit()
        +associateToken()
        +lockAsset()
        +unlockAsset()
    }
    class CradleAccountFactory {
        +createAccount()
        +createAccountForUser()
        +accountsByController
    }
    CradleAccountFactory ..> CradleAccount : Creates
```

### 3. Lending & Borrowing
The lending system uses `AssetLendingPool` to manage liquidity.
- **Deposit**: Users deposit assets into the pool's reserve `CradleAccount`.
- **Borrow**: Users borrow against collateral held in their own `CradleAccount` (which gets locked).

```mermaid
sequenceDiagram
    participant User
    participant UserAccount as User's CradleAccount
    participant Pool as AssetLendingPool
    participant Reserve as Pool Reserve Account

    User->>Pool: deposit(asset, amount)
    Pool->>UserAccount: transferAsset(Reserve, asset, amount)
    Pool->>Pool: mint yield tokens to User

    User->>Pool: borrow(asset, amount)
    Pool->>UserAccount: checkCollateral()
    Pool->>UserAccount: lockAsset(collateral, amount)
    Pool->>Reserve: transferAsset(UserAccount, asset, amount)
```

### 4. Orderbook Settlement
`CradleOrderBookSettler` allows for atomic settlement of trades matched off-chain.
- It moves funds between the Buyer's and Seller's `CradleAccount`s.
- It collects fees.

```mermaid
sequenceDiagram
    participant OffChainMatcher
    participant Settler as CradleOrderBookSettler
    participant Buyer as "Buyer Account"
    participant Seller as "Seller Account"
    participant Treasury

    OffChainMatcher->>Settler: settleOrder(buyer, seller, assets...)
    Settler->>Buyer: unlockAsset(askAsset)
    Settler->>Seller: unlockAsset(bidAsset)
    
    Settler->>Buyer: transferAsset(Seller, askAsset, netAmount)
    Settler->>Buyer: transferAsset(Treasury, askAsset, fee)
    
    Settler->>Seller: transferAsset(Buyer, bidAsset, netAmount)
    Settler->>Seller: transferAsset(Treasury, bidAsset, fee)
```
