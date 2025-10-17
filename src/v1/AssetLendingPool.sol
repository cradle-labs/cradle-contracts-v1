// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {CradleAccount, ICradleAccount} from "./CradleAccount.sol";
import {AbstractCradleAssetManager} from "./AbstractCradleAssetManager.sol";

/**
 * The AssetLendingPool holds util logic for the lending pools
 * to be inherited and used in different ways by the CradleBridgedAssetPools and CradleNativeAssetPools
 */
contract AssetLendingPool {
    // Use 10000 for basis points (1 bp = 0.01%, so 100 = 1%, 10000 = 100%)
    uint256 public constant BASE_POINT = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365.25 days; // 31557600 seconds

    address public PROTOCOL;
    CradleAccount public reserve;

    // Rates stored as basis points (e.g., 500 = 5%)
    uint64 public apr;
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

    modifier onlyProtocol() {
        require(msg.sender == PROTOCOL, "Unauthorised");
        _;
    }

    constructor(
        address _protocol,
        uint64 _apr,
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
        string memory lendingPool
    ) {
        PROTOCOL = _protocol;
        apr = _apr;
        ltv = _ltv;
        optimalUtilization = _optimalUtilization;
        baseRate = _baseRate;
        slope1 = _slope1;
        slope2 = _slope2;
        liquidationThreshold = _liquidationThreshold;
        liquidationDiscount = _liquidationDiscount;
        reserveFactor = _reserveFactor;
        lendingAsset = _lending;
        reserve = new CradleAccount(lendingPool);

        // Start indices at 1e18 for WAD math precision
        borrowIndex = 1e18;
        supplyIndex = 1e18;
        lastUpdatedTimestamp = block.timestamp;

        // Note: Uncomment if CradleLendingAssetManager is available
        // yieldBearingAsset = new CradleLendingAssetManager(yieldAsset, yieldAssetSymbol);

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
        borrowIndex += borrowGrowth;

        // Update supply index
        uint256 supplyRate = getSupplyRate();
        uint256 supplyGrowth = (supplyIndex * supplyRate * secondsElapsed) / (BASE_POINT * SECONDS_PER_YEAR);
        supplyIndex += supplyGrowth;

        lastUpdatedTimestamp = block.timestamp;
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
    function updateOracle(address asset, uint256 multiplier) public onlyProtocol {
        assetMultiplierOracle[asset] = multiplier;
    }

    /**
     * get asset multiplier against base token
     */
    function getAssetMultiplier(address asset) public view returns (uint256) {
        return assetMultiplierOracle[asset];
    }

    function deposit(address user, uint256 amount) public onlyProtocol {
        updateIndices();

        uint256 yieldTokensToMint = amount / supplyIndex;

        totalSupplied += amount;

        ICradleAccount(user).transferAsset(address(reserve), lendingAsset.token(), amount);

        yieldBearingAsset.airdropTokens(user, uint64(yieldTokensToMint));
    }

    function withdraw(address user, uint256 yieldTokenAmount) public onlyProtocol {
        updateIndices();

        uint256 underlyingAmount = (yieldTokenAmount * supplyIndex);

        require(totalSupplied - totalBorrowed >= underlyingAmount, "Insufficient liquidity");

        totalSupplied -= underlyingAmount;

        yieldBearingAsset.wipe(uint64(yieldTokenAmount), user);

        reserve.transferAsset(user, lendingAsset.token(), underlyingAmount);
    }

    function borrow(address user, uint256 collateralAmount, address collateralAsset) public onlyProtocol {
        updateIndices();

        uint256 multiplier = getAssetMultiplier(collateralAsset);
        uint256 collateralValue = collateralAmount * multiplier;
        uint256 maxBorrow = (collateralValue * ltv) / BASE_POINT;

        require(totalSupplied - totalBorrowed >= collateralValue, "Insufficient liquidity");

        require(ICradleAccount(user).getLoanAmount(address(this), collateralAsset) == 0, "Existing unpaid dept");

        ICradleAccount(user).addLoanLock(address(this), collateralAsset, maxBorrow, collateralAmount, borrowIndex);

        totalBorrowed += maxBorrow;

        reserve.transferAsset(user, lendingAsset.token(), maxBorrow);
    }

    function repay(address user, address collateralizedAsset, uint256 repayAmount) public onlyProtocol {
        updateIndices();

        uint256 multiplier = assetMultiplierOracle[collateralizedAsset];
        uint256 collateralAmount = repayAmount / multiplier;

        uint256 loanAmount = ICradleAccount(user).getLoanAmount(address(this), collateralizedAsset);
        uint256 loanIndex = ICradleAccount(user).getLoanBlockIndex(address(this), collateralizedAsset);

        uint256 repaymentDept = calculateCurrentDebt(repayAmount, loanIndex);

        ICradleAccount(user).removeLoanLock(
            address(this), collateralizedAsset, repaymentDept, collateralAmount, borrowIndex
        );

        // Step 6: Calculate reserve fee
        uint256 interestPaid = repaymentDept - repayAmount;
        uint256 reserveAmount = (interestPaid * reserveFactor) / BASE_POINT;
        uint256 toPool = repaymentDept - reserveAmount;

        totalBorrowed -= repayAmount;

        ICradleAccount(user).transferAsset(address(reserve), lendingAsset.token(), repaymentDept);
    }

    function liquidate(address liquidator, address borrower, uint256 debtToCover, address collateralAsset)
        public
        onlyProtocol
    {
        updateIndices();

        uint256 multiplier = assetMultiplierOracle[collateralAsset];
        uint256 collateralAmountToReceive = debtToCover / multiplier;
        uint256 collateralAmountWithBonus = collateralAmountToReceive * (BASE_POINT + liquidationDiscount) / BASE_POINT;

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
    }
}
