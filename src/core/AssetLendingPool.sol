// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {CradleAccount, ICradleAccount} from "./CradleAccount.sol";
import { AbstractContractAuthority } from "./AbstractContractAuthority.sol";
import {CradleLendingAssetManager} from "./CradleLendingAssetManager.sol";
import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";
import {ReentrancyGuard} from "@openzeppelin/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

/**
 * The AssetLendingPool holds util logic for the lending pools
 * to be inherited and used in different ways by the CradleBridgedAssetPools and CradleNativeAssetPools
 */
contract AssetLendingPool is AbstractContractAuthority, ReentrancyGuard {
    // Use 10000 for basis points (1 bp = 0.01%, so 100 = 1%, 10000 = 100%)
    uint256 public constant BASE_POINT = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365.25 days; // 31557600 seconds

    // Maximum index value to prevent overflow (set to ~10^20 to allow for extreme growth scenarios)
    uint256 public constant MAX_INDEX = 1e20;

    CradleAccount public reserve;
    CradleAccount public treasury;

    // Rates stored as basis points (e.g., 500 = 5%)
    uint64 public ltv;
    uint64 public optimalUtilization; // e.g., 8000 = 80%
    uint64 public baseRate; // e.g., 200 = 2%
    uint64 public slope1; // e.g., 400 = 4%
    uint64 public slope2; // e.g., 6000 = 60%
    uint64 public liquidationThreshold;
    uint64 public liquidationDiscount;
    uint64 public reserveFactor; // e.g., 1000 = 10%

    AbstractCradleAssetManager public lendingAsset;
    AbstractCradleAssetManager public yieldBearingAsset;

    // Indices start at 1e18 for precision (WAD math)
    uint256 public borrowIndex;
    uint256 public supplyIndex;
    uint256 public lastUpdatedTimestamp;

    uint256 public totalBorrowed;
    uint256 public totalSupplied;

    mapping(address => uint256) public assetMultiplierOracle;

    // Events
    event Deposited(address indexed user, uint256 amount, uint256 yieldTokensMinted);
    event Withdrawn(address indexed user, uint256 yieldTokensBurned, uint256 underlyingAmount);
    event Borrowed(address indexed user, address indexed collateralAsset, uint256 collateralAmount, uint256 borrowAmount, uint256 borrowIndex);
    event Repaid(address indexed user, address indexed collateralAsset, uint256 repaidAmount, uint256 principalRepaid, uint256 interestPaid);
    event Liquidated(address indexed liquidator, address indexed borrower, address indexed collateralAsset, uint256 debtCovered, uint256 collateralSeized);
    event IndicesUpdated(uint256 newBorrowIndex, uint256 newSupplyIndex, uint256 timestamp);
    event OracleUpdated(address indexed asset, uint256 newMultiplier);


    constructor(
        uint64 _ltv,
        uint64 _optimalUtilization,
        uint64 _baseRate,
        uint64 _slope1,
        uint64 _slope2,
        uint64 _liquidationThreshold,
        uint64 _liquidationDiscount,
        uint64 _reserveFactor,
        AbstractCradleAssetManager _lending,
        string memory yieldAsset,
        string memory yieldAssetSymbol,
        string memory lendingPool,
        address aclContract,
        uint64 allowList
    )
    AbstractContractAuthority (aclContract, allowList)
     {
        ltv = _ltv;
        optimalUtilization = _optimalUtilization;
        baseRate = _baseRate;
        slope1 = _slope1;
        slope2 = _slope2;
        liquidationThreshold = _liquidationThreshold;
        liquidationDiscount = _liquidationDiscount;
        reserveFactor = _reserveFactor;
        lendingAsset = _lending;
        reserve = new CradleAccount(lendingPool, aclContract, uint64(4));
        string memory treasuryName = string(abi.encodePacked(lendingPool, "", "treasury"));
        treasury = new CradleAccount(treasuryName, aclContract, uint64(4));

        // Start indices at 1e18 for WAD math precision
        borrowIndex = 1e18;
        supplyIndex = 1e18;
        lastUpdatedTimestamp = block.timestamp;

        yieldBearingAsset = new CradleLendingAssetManager(yieldAsset, yieldAssetSymbol, aclContract, uint64(1));

        totalBorrowed = 0;
        totalSupplied = 0;
    }

    /**
     * @notice Calculate current utilization rate
     * @return Utilization rate in basis points (e.g., 7000 = 70%)
     */
    function getUtilization() public view returns (uint256) {
        if (totalSupplied == 0) {
            return 0;
        }
        // Return as basis points: (borrowed * BASE_POINT) / supplied
        return (totalBorrowed * BASE_POINT) / totalSupplied;
    }

    /**
     * @notice Calculate current borrow rate based on utilization
     * @return Borrow rate in basis points per year (e.g., 500 = 5% APR)
     */
    function getBorrowRate() public view returns (uint256) {
        uint256 currentUtilization = getUtilization();

        if (currentUtilization < optimalUtilization) {
            // Below optimal: baseRate + (U / optimalU) * slope1
            // Multiply first, divide last for precision
            return baseRate + (currentUtilization * slope1) / optimalUtilization;
        } else {
            // Above optimal: baseRate + slope1 + ((U - optimalU) / (1 - optimalU)) * slope2
            uint256 excessUtilization = currentUtilization - optimalUtilization;
            uint256 excessRange = BASE_POINT - optimalUtilization;
            return baseRate + slope1 + (excessUtilization * slope2) / excessRange;
        }
    }

    /**
     * @notice Calculate supply rate (what lenders earn)
     * @return Supply rate in basis points per year
     */
    function getSupplyRate() public view returns (uint256) {
        uint256 currentUtilization = getUtilization();
        uint256 borrowRate = getBorrowRate();

        // supplyRate = borrowRate * utilization * (1 - reserveFactor)
        // All in basis points, need to divide by BASE_POINT twice
        return (borrowRate * currentUtilization * (BASE_POINT - reserveFactor)) / (BASE_POINT * BASE_POINT);
    }

    /**
     * @notice Update the borrow index based on time elapsed and current borrow rate
     */
    function updateBorrowIndex() public {
        uint256 secondsElapsed = block.timestamp - lastUpdatedTimestamp;

        if (secondsElapsed == 0) {
            return; // No time passed, no update needed
        }

        uint256 borrowRate = getBorrowRate();

        // Index growth = currentIndex * ratePerSecond * secondsElapsed
        // ratePerSecond = borrowRate / BASE_POINT / SECONDS_PER_YEAR
        // Rearranged: borrowIndex * borrowRate * secondsElapsed / (BASE_POINT * SECONDS_PER_YEAR)

        uint256 indexGrowth = (borrowIndex * borrowRate * secondsElapsed) / (BASE_POINT * SECONDS_PER_YEAR);

        borrowIndex += indexGrowth;
        lastUpdatedTimestamp = block.timestamp;
    }

    /**
     * @notice Update the supply index based on time elapsed and current supply rate
     */
    function updateSupplyIndex() public {
        uint256 secondsElapsed = block.timestamp - lastUpdatedTimestamp;

        if (secondsElapsed == 0) {
            return;
        }

        uint256 supplyRate = getSupplyRate();

        // Same calculation as borrow index but with supply rate
        uint256 indexGrowth = (supplyIndex * supplyRate * secondsElapsed) / (BASE_POINT * SECONDS_PER_YEAR);

        supplyIndex += indexGrowth;
        lastUpdatedTimestamp = block.timestamp;
    }

    /**
     * @notice Update both indices atomically
     * @dev Should be called before any state-changing operation (borrow, repay, deposit, withdraw)
     */
    function updateIndices() public {
        uint256 secondsElapsed = block.timestamp - lastUpdatedTimestamp;

        if (secondsElapsed == 0) {
            return;
        }

        // Update borrow index
        uint256 borrowRate = getBorrowRate();
        uint256 borrowGrowth = (borrowIndex * borrowRate * secondsElapsed) / (BASE_POINT * SECONDS_PER_YEAR);
        uint256 newBorrowIndex = borrowIndex + borrowGrowth;

        // Prevent overflow - if index grows too large, cap it
        require(newBorrowIndex <= MAX_INDEX, "Borrow index overflow - contact protocol admin");
        borrowIndex = newBorrowIndex;

        // Update supply index
        uint256 supplyRate = getSupplyRate();
        uint256 supplyGrowth = (supplyIndex * supplyRate * secondsElapsed) / (BASE_POINT * SECONDS_PER_YEAR);
        uint256 newSupplyIndex = supplyIndex + supplyGrowth;

        require(newSupplyIndex <= MAX_INDEX, "Supply index overflow - contact protocol admin");
        supplyIndex = newSupplyIndex;

        lastUpdatedTimestamp = block.timestamp;

        emit IndicesUpdated(borrowIndex, supplyIndex, block.timestamp);
    }

    /**
     * @notice Calculate a user's current debt including accrued interest
     * @param userPrincipal The principal amount borrowed
     * @param userBorrowIndex The borrow index when user borrowed
     * @return Current debt amount
     */
    function calculateCurrentDebt(uint256 userPrincipal, uint256 userBorrowIndex) public view returns (uint256) {
        // debt = principal * (currentIndex / userIndex)
        return (userPrincipal * borrowIndex) / userBorrowIndex;
    }

    /**
     * @notice Calculate a user's current deposit value including accrued interest
     * @param userShares The amount of yield-bearing tokens user holds
     * @return Current deposit value
     */
    function calculateCurrentDeposit(uint256 userShares) public view returns (uint256) {
        // value = shares * currentSupplyIndex / 1e18
        // Shares were minted as: depositAmount * 1e18 / supplyIndex
        return (userShares * supplyIndex) / 1e18;
    }

    /**
     * @notice Calculate health factor for a position
     * @param collateralValue Total collateral value in base currency
     * @param borrowedValue Total borrowed value in base currency
     * @return Health factor scaled by 1e18 (1e18 = 1.0, below 1e18 = liquidatable)
     */
    function calculateHealthFactor(uint256 collateralValue, uint256 borrowedValue) public view returns (uint256) {
        if (borrowedValue == 0) {
            return type(uint256).max; // No debt = infinite health
        }

        // HF = (collateralValue * liquidationThreshold / BASE_POINT) / borrowedValue
        // Scale by 1e18 for precision
        return (collateralValue * liquidationThreshold * 1e18) / (borrowedValue * BASE_POINT);
    }

    /**
     * updates the asset's multiplier allowing for borrowing using different assets as collateral
     */
    function updateOracle(address asset, uint256 multiplier) public onlyAuthorized {
        assetMultiplierOracle[asset] = multiplier;
        emit OracleUpdated(asset, multiplier);
    }

    /**
     * get asset multiplier against base token
     */
    function getAssetMultiplier(address asset) public view returns (uint256) {
        return assetMultiplierOracle[asset];
    }

    /**
     * @notice Get user's deposit position details
     * @param user The user's CradleAccount address
     * @return yieldTokenBalance The amount of yield-bearing tokens held
     * @return underlyingValue The current value in underlying tokens
     * @return currentSupplyAPY The current supply APY in basis points
     */
    function getUserDepositPosition(address user) external view returns (
        uint256 yieldTokenBalance,
        uint256 underlyingValue,
        uint256 currentSupplyAPY
    ) {
        yieldTokenBalance = IERC20(yieldBearingAsset.token()).balanceOf(user);
        underlyingValue = calculateCurrentDeposit(yieldTokenBalance);
        currentSupplyAPY = getSupplyRate();
    }

    /**
     * @notice Get user's borrow position details
     * @param user The user's CradleAccount address
     * @param collateralAsset The collateral asset address
     * @return principalBorrowed The principal amount borrowed
     * @return currentDebt The current debt including interest
     * @return collateralAmount The amount of collateral locked
     * @return healthFactor The position's health factor (1e18 = 1.0)
     * @return borrowIndex The user's borrow index
     */
    function getUserBorrowPosition(address user, address collateralAsset) external view returns (
        uint256 principalBorrowed,
        uint256 currentDebt,
        uint256 collateralAmount,
        uint256 healthFactor,
        uint256 borrowIndex
    ) {
        principalBorrowed = ICradleAccount(user).getLoanAmount(address(this), collateralAsset);
        borrowIndex = ICradleAccount(user).getLoanBlockIndex(address(this), collateralAsset);
        collateralAmount = ICradleAccount(user).getCollateral(address(this), collateralAsset);

        if (principalBorrowed > 0) {
            currentDebt = calculateCurrentDebt(principalBorrowed, borrowIndex);

            uint256 multiplier = assetMultiplierOracle[collateralAsset];
            uint256 collateralValue = collateralAmount * multiplier;
            healthFactor = calculateHealthFactor(collateralValue, currentDebt);
        } else {
            currentDebt = 0;
            healthFactor = type(uint256).max;
        }
    }

    /**
     * @notice Get maximum borrow amount for a user given collateral
     * @param collateralAmount The amount of collateral
     * @param collateralAsset The collateral asset address
     * @return maxBorrowAmount The maximum amount that can be borrowed
     */
    function getMaxBorrowAmount(uint256 collateralAmount, address collateralAsset) external view returns (uint256) {
        uint256 multiplier = assetMultiplierOracle[collateralAsset];
        uint256 collateralValue = collateralAmount * multiplier;
        return (collateralValue * ltv) / BASE_POINT;
    }

    /**
     * @notice Check if a position is liquidatable
     * @param user The user's CradleAccount address
     * @param collateralAsset The collateral asset address
     * @return isLiquidatable True if position can be liquidated
     * @return healthFactor The current health factor
     */
    function isPositionLiquidatable(address user, address collateralAsset) external view returns (
        bool isLiquidatable,
        uint256 healthFactor
    ) {
        uint256 principalBorrowed = ICradleAccount(user).getLoanAmount(address(this), collateralAsset);

        if (principalBorrowed == 0) {
            return (false, type(uint256).max);
        }

        uint256 borrowIndex = ICradleAccount(user).getLoanBlockIndex(address(this), collateralAsset);
        uint256 collateralAmount = ICradleAccount(user).getCollateral(address(this), collateralAsset);

        uint256 currentDebt = calculateCurrentDebt(principalBorrowed, borrowIndex);
        uint256 multiplier = assetMultiplierOracle[collateralAsset];
        uint256 collateralValue = collateralAmount * multiplier;

        healthFactor = calculateHealthFactor(collateralValue, currentDebt);
        isLiquidatable = healthFactor < 1e18;
    }

    /**
     * @notice Get pool statistics
     * @return totalSupply Total assets supplied to the pool
     * @return totalBorrow Total assets borrowed from the pool
     * @return availableLiquidity Available liquidity for borrowing
     * @return utilizationRate Current utilization rate in basis points
     * @return supplyAPY Current supply APY in basis points
     * @return borrowAPY Current borrow APY in basis points
     */
    function getPoolStats() external view returns (
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 availableLiquidity,
        uint256 utilizationRate,
        uint256 supplyAPY,
        uint256 borrowAPY
    ) {
        totalSupply = totalSupplied;
        totalBorrow = totalBorrowed;
        availableLiquidity = totalSupplied > totalBorrowed ? totalSupplied - totalBorrowed : 0;
        utilizationRate = getUtilization();
        supplyAPY = getSupplyRate();
        borrowAPY = getBorrowRate();
    }

    function deposit(address user, uint256 amount) public onlyAuthorized nonReentrant {
        updateIndices();

        // Fixed: Multiply before divide to prevent precision loss
        // yieldTokens = amount * 1e18 / supplyIndex
        uint256 yieldTokensToMint = (amount * 1e18) / supplyIndex;

        totalSupplied += amount;

        ICradleAccount(user).transferAsset(address(reserve), lendingAsset.token(), amount);

        yieldBearingAsset.airdropTokens(user, uint64(yieldTokensToMint));

        emit Deposited(user, amount, yieldTokensToMint);
    }

    function withdraw(address user, uint256 yieldTokenAmount) public onlyAuthorized nonReentrant {
        updateIndices();

        // Fixed: Divide by 1e18 to get actual underlying amount
        // underlyingAmount = yieldTokens * supplyIndex / 1e18
        uint256 underlyingAmount = (yieldTokenAmount * supplyIndex) / 1e18;

        require(totalSupplied - totalBorrowed >= underlyingAmount, "Insufficient liquidity");

        totalSupplied -= underlyingAmount;

        yieldBearingAsset.wipe(uint64(yieldTokenAmount), user);

        reserve.transferAsset(user, lendingAsset.token(), underlyingAmount);

        emit Withdrawn(user, yieldTokenAmount, underlyingAmount);
    }

    function borrow(address user, uint256 collateralAmount, address collateralAsset) public onlyAuthorized nonReentrant {
        updateIndices();

        uint256 multiplier = getAssetMultiplier(collateralAsset);
        uint256 collateralValue = collateralAmount * multiplier;
        uint256 maxBorrow = (collateralValue * ltv) / BASE_POINT;

        require(totalSupplied - totalBorrowed >= maxBorrow, "Insufficient liquidity");

        require(ICradleAccount(user).getLoanAmount(address(this), collateralAsset) == 0, "Existing unpaid dept");

        ICradleAccount(user).addLoanLock(address(this), collateralAsset, maxBorrow, collateralAmount, borrowIndex);

        totalBorrowed += maxBorrow;

        reserve.transferAsset(user, lendingAsset.token(), maxBorrow);

        emit Borrowed(user, collateralAsset, collateralAmount, maxBorrow, borrowIndex);
    }

    function repay(address user, address collateralizedAsset, uint256 repayAmount) public onlyAuthorized nonReentrant {
        updateIndices();

        uint256 loanPrincipal = ICradleAccount(user).getLoanAmount(address(this), collateralizedAsset);
        uint256 loanIndex = ICradleAccount(user).getLoanBlockIndex(address(this), collateralizedAsset);
        uint256 collateralLocked = ICradleAccount(user).getCollateral(address(this), collateralizedAsset);

        require(loanPrincipal > 0, "No active loan");

        // Calculate current debt with interest
        uint256 currentDebt = calculateCurrentDebt(loanPrincipal, loanIndex);

        require(repayAmount <= currentDebt, "Repay amount exceeds debt");

        // Calculate how much principal is being repaid
        uint256 principalRepaid = (repayAmount * loanIndex) / borrowIndex;

        // Calculate proportional collateral to unlock
        uint256 collateralToUnlock = (collateralLocked * principalRepaid) / loanPrincipal;

        // Remove loan lock with updated values
        ICradleAccount(user).removeLoanLock(
            address(this), collateralizedAsset, principalRepaid, collateralToUnlock, borrowIndex
        );

        // Calculate interest and reserve split
        uint256 interestPaid = repayAmount > principalRepaid ? repayAmount - principalRepaid : 0;
        uint256 reserveAmount = (interestPaid * reserveFactor) / BASE_POINT;
        uint256 toPool = repayAmount - reserveAmount;

        totalBorrowed -= principalRepaid;

        ICradleAccount(user).transferAsset(address(reserve), lendingAsset.token(), toPool);
        if (reserveAmount > 0) {
            ICradleAccount(user).transferAsset(address(treasury), lendingAsset.token(), reserveAmount);
        }

        emit Repaid(user, collateralizedAsset, repayAmount, principalRepaid, interestPaid);
    }

    function liquidate(address liquidator, address borrower, uint256 debtToCover, address collateralAsset)
        public
        onlyAuthorized
        nonReentrant
    {
        updateIndices();

        uint256 multiplier = assetMultiplierOracle[collateralAsset];
        // Fixed: Multiply by 1e18 then divide by multiplier to get correct collateral amount
        // If debtToCover = 1000 USDC and multiplier = 2000 (1 ETH = 2000 USDC scaled to 1e18)
        // collateralAmount = (1000 * 1e18) / 2000 = 0.5 ETH
        uint256 collateralAmountToReceive = (debtToCover * 1e18) / multiplier;
        uint256 collateralAmountWithBonus = (collateralAmountToReceive * (BASE_POINT + liquidationDiscount)) / BASE_POINT;

        uint256 positionLoanAmount = ICradleAccount(borrower).getLoanAmount(address(this), collateralAsset);
        uint256 positionCollateralAmount = ICradleAccount(borrower).getCollateral(address(this), collateralAsset);
        uint256 positionBorrowIndex = ICradleAccount(borrower).getLoanBlockIndex(address(this), collateralAsset);

        uint256 positionCollateralValue = positionCollateralAmount * multiplier;

        uint256 currentDebt = calculateCurrentDebt(positionLoanAmount, positionBorrowIndex);

        // Step 2: Calculate borrower's health factor
        uint256 healthFactor = calculateHealthFactor(positionCollateralValue, currentDebt);
        require(healthFactor < 1e18, "Position is  healthy, cannot liquidate");

        uint256 principalReduction = (debtToCover * positionBorrowIndex) / borrowIndex;
        ICradleAccount(borrower).removeLoanLock(
            address(this), collateralAsset, principalReduction, collateralAmountWithBonus, borrowIndex
        );

        totalBorrowed -= debtToCover;

        ICradleAccount(liquidator).transferAsset(address(reserve), lendingAsset.token(), debtToCover);

        ICradleAccount(borrower).transferAsset(liquidator, collateralAsset, collateralAmountWithBonus);

        emit Liquidated(liquidator, borrower, collateralAsset, debtToCover, collateralAmountWithBonus);
    }
}
