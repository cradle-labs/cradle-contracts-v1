# Hedera Contract Verification Scripts

This directory contains scripts for verifying deployed contracts on Hedera using Sourcify.

## Scripts

### 1. `verify-contract.sh` - Single Contract Verification

Verify a single deployed contract with custom constructor arguments.

**Usage:**
```bash
./scripts/verify-contract.sh <contract_name> <contract_address> [constructor_args]
```

**Examples:**

```bash
# Contract with no constructor arguments
./scripts/verify-contract.sh AccessController 0x1234567890abcdef1234567890abcdef12345678

# Contract with single address argument (AssetFactory)
./scripts/verify-contract.sh AssetFactory 0x1234567890abcdef1234567890abcdef12345678 0xACLAddress123

# Contract with string arguments (BaseAsset)
./scripts/verify-contract.sh BaseAsset 0x1234567890abcdef1234567890abcdef12345678 '"Wrapped Token"' '"WTKN"' 0xACLAddr 1

# Contract with multiple arguments (CradleAccount)
./scripts/verify-contract.sh CradleAccount 0x1234567890abcdef1234567890abcdef12345678 '"controller_123"' 0xACLAddr 1

# Contract with many arguments (AssetLendingPool)
./scripts/verify-contract.sh AssetLendingPool 0x1234567890abcdef1234567890abcdef12345678 \
  0xACL 0xYieldAsset 0xLendingAsset 7000 8000 500 100000000000000000 200000000000000000 9500 8000
```

**Available Contracts:**
- AccessController
- AssetFactory
- AssetLendingPool
- BaseAsset
- BridgedAsset
- BridgedAssetIssuer
- CradleAccount
- CradleAccountFactory
- CradleLendingAssetManager
- CradleListingFactory
- CradleNativeListing
- CradleOrderBookSettler
- LendingPoolFactory
- NativeAsset
- NativeAssetIssuer

### 2. `verify-batch.sh` - Interactive Batch Verification

Interactive script for verifying multiple contracts in one session.

**Usage:**
```bash
./scripts/verify-batch.sh
```

**Features:**
- Interactive menu system
- Add multiple contracts to verification queue
- Automatic constructor argument prompts based on contract type
- Batch verification of all queued contracts
- Summary report of successful/failed verifications

**Workflow:**
1. Run the script
2. Select "Add contract to verification queue"
3. Choose contract type
4. Enter contract address
5. Follow prompts for constructor arguments
6. Repeat for additional contracts
7. Select "Start batch verification" to verify all at once

## Constructor Arguments Reference

### AccessController
```
No constructor arguments
```

### AssetFactory, CradleAccountFactory, CradleListingFactory, LendingPoolFactory
```
constructor(address aclContract)
```

### BaseAsset, BridgedAsset, NativeAsset, CradleLendingAssetManager
```
constructor(string name, string symbol, address aclContract, uint64 allowList)
```

### BridgedAssetIssuer, NativeAssetIssuer
```
constructor(address aclContract, address treasury, address reserveToken)
```

### CradleAccount
```
constructor(string controller, address aclContract, uint64 allowList)
```

### CradleOrderBookSettler
```
constructor(address aclContract, address treasury)
```

### CradleNativeListing
```
constructor(
    address feeCollector,
    address reserve,
    uint256 maxSupply,
    address asset,
    address purchaseAsset,
    uint256 purchasePrice,
    address beneficiary,
    address shadowAsset
)
```

### AssetLendingPool
```
constructor(
    address aclContract,
    address yieldBearingAsset,
    address lendingAsset,
    uint256 ltv,
    uint256 liquidationThreshold,
    uint256 liquidationDiscount,
    uint256 baseRate,
    uint256 slope1,
    uint256 slope2,
    uint256 optimalUtilization
)
```

## Configuration

Both scripts are configured for Hedera Testnet by default:
- **Chain ID:** 296
- **Verifier:** sourcify
- **Verifier URL:** https://server-verify.hashscan.io/

To verify on mainnet, update the `CHAIN_ID` variable in the scripts:
```bash
CHAIN_ID=295  # Hedera Mainnet
```

## Tips

1. **String Arguments:** Always wrap string arguments in quotes
   ```bash
   '"My Token"' '"MTK"'
   ```

2. **Address Format:** Ensure addresses are in proper format
   ```bash
   0x1234567890abcdef1234567890abcdef12345678
   ```

3. **Wait After Deployment:** Allow a few seconds after deployment before verifying

4. **Compilation Settings:** Verification requires matching compilation settings used during deployment

5. **View Results:** After successful verification, view on HashScan:
   - Testnet: `https://hashscan.io/testnet/contract/<address>`
   - Mainnet: `https://hashscan.io/mainnet/contract/<address>`

## Troubleshooting

**Verification Failed:**
- Ensure contract address is correct
- Verify constructor arguments match deployment exactly
- Check that contract was compiled with same Solidity version
- Wait a few moments after deployment before verifying
- Ensure network connection is stable

**Constructor Args Encoding:**
- Use `cast abi-encode` to manually test argument encoding:
  ```bash
  cast abi-encode "constructor(address)" 0x1234...
  ```

**View Verification Status:**
- Check HashScan for verification status
- Sourcify maintains verification records
