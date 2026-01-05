# Cradle Protocol Deployer Checklist

This checklist outlines the operational steps required to fully instantiate the Cradle Protocol ecosystem after the initial deployment of factories and core infrastructure.

**Note**: All "Contracts" mentioned below refer to the smart contract instances, while "Tokens" refer to the underlying Hedera Token Service (HTS) assets.

## 1. Pre-Deployment Verification
Ensure the following core contracts are deployed and you have their addresses:
- [ ] `AccessController`
- [ ] `CradleOrderBookSettler`
- [ ] `AssetFactory`
- [ ] `NativeAssetIssuerFactory`
- [ ] `BridgedAssetIssuerFactory`
- [ ] `CradleAccountFactory`
- [ ] `LendingPoolFactory`
- [ ] `CradleListingFactory`

---

## 2. Asset Issuance (Native & Bridged)

### A. Create an Issuer
*Use this to create an entity capable of issuing multiple assets.*

1.  **Action**: Call `createNativeAssetIssuer` (or `createBridgedAssetIssuer`) on the respective Factory.
    *   **Inputs**:
        *   `treasury`: Address of a `CradleAccount` to act as treasury.
        *   `aclContract`: Address of `AccessController`.
        *   `allowList`: Access level (usually 0 or 1).
        *   `reserveToken`: Address of the token used for reserves (e.g., USDC, HBAR wrapper).
2.  **Hedera Requirements**:
    *   **Association**: The `treasury` account must be associated with the `reserveToken`.

### B. Issue an Asset
*Use the Issuer created above to mint a new HTS token.*

1.  **Action**: Call `createAsset` on the `NativeAssetIssuer` (or `BridgedAssetIssuer`).
    *   **Inputs**: `name`, `symbol`, `aclContract`, `allowList`.
    *   **Value**: Send HBAR with the transaction (approx 20-30 HBAR) to cover HTS token creation fees.
2.  **Result**:
    *   Deploys a `NativeAsset` (or `BridgedAsset`) contract.
    *   Creates a new HTS Token.
3.  **Hedera Requirements**:
    *   **Keys**: The `NativeAsset` contract automatically holds all HTS keys (Supply, Wipe, etc.). No manual key management needed.

---

## 3. Account Creation
*Create smart wallets for users, protocols, or operational reserves.*

1.  **Action**: Call `createAccount` on `CradleAccountFactory`.
    *   **Inputs**: `controller` (string ID), `accountAllowList`.
2.  **Hedera Requirements**:
    *   **Funding**: Send HBAR to the new `CradleAccount` address immediately. It needs HBAR to pay for token associations and transfers.
    *   **Association**: Call `associateToken(tokenAddress)` on the `CradleAccount` for **every** token it intends to hold.

---

## 4. Lending Pool Creation

### A. Prerequisites
1.  **Lending Asset**: The token to be lent (e.g., USDC).
2.  **Yield Token**: You must deploy a `CradleLendingAssetManager` contract first to represent the "cToken" (e.g., cUSDC).
    *   *Note*: This contract creates an HTS token in its constructor. Send HBAR with deployment.

### B. Create Pool
1.  **Action**: Call `createPool` on `LendingPoolFactory`.
    *   **Inputs**: Risk parameters (`ltv`, `baseRate`, etc.), `lendingAsset`, `yieldContract` (address from step A).
2.  **Post-Creation Setup (CRITICAL)**:
    *   The pool automatically deploys two `CradleAccount`s: `reserve` and `treasury`.
    *   **Retrieve Addresses**: Query `getReserveAccount()` and `getTreasuryAccount()` on the new Pool contract.
3.  **Hedera Requirements**:
    *   **Fund Reserve**: Send HBAR to the `reserve` account.
    *   **Fund Treasury**: Send HBAR to the `treasury` account.
    *   **Associate Reserve**: Call `associateToken(lendingAsset)` on the `reserve` account.
    *   **Associate Treasury**: Call `associateToken(lendingAsset)` on the `treasury` account.

---

## 5. Listing Creation (IDO/Sale)

### A. Prerequisites
1.  **Reserve Account**: Create a `CradleAccount` to hold the tokens for sale (Step 3).
2.  **Assets**:
    *   `listed_asset`: The token being sold.
    *   `purchase_asset`: The token accepted as payment.
    *   `participation_asset`: A "shadow" token used for tracking participation (create via `AssetFactory`).

### B. Create Listing
1.  **Action**: Call `createListing` on `CradleListingFactory`.
    *   **Inputs**: `reserve` (address from A), `max_supply`, `listed_asset`, `purchase_asset`, `price`, `beneficiary`, `participation_asset`.
2.  **Hedera Requirements**:
    *   **Fund Reserve**: Ensure the `reserve` account has HBAR.
    *   **Associate Reserve**: Call `associateToken` on the `reserve` account for:
        *   `listed_asset`
        *   `purchase_asset`
        *   `participation_asset`
    *   **Fund Sale**: Transfer the `max_supply` of `listed_asset` into the `reserve` account.
    *   **Status**: Call `updateListingStatus(1)` (Open) to start the sale.

---

## Summary of Token Associations

| Contract Type | Must Associate With | Why? |
| :--- | :--- | :--- |
| **Issuer Treasury** | Reserve Token | To hold backing assets. |
| **Lending Reserve** | Lending Asset | To hold liquidity. |
| **Lending Treasury** | Lending Asset | To collect protocol fees. |
| **Listing Reserve** | Listed Asset | To distribute to buyers. |
| **Listing Reserve** | Purchase Asset | To collect payment. |
| **Listing Reserve** | Participation Asset | To track buyers. |
| **User Account** | Any Asset | To hold balance. |

