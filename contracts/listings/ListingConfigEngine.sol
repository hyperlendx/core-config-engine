// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { Ownable } from '../dependencies/Ownable.sol';
import { ConfiguratorInputTypes } from '../dependencies/types/ConfiguratorInputTypes.sol';

import { IOracle } from '../dependencies/interfaces/IOracle.sol';
import { IPriceSource } from '../dependencies/interfaces/IPriceSource.sol';
import { IPoolAddressesProvider } from '../dependencies/interfaces/IPoolAddressesProvider.sol';
import { IPoolConfigurator } from '../dependencies/interfaces/IPoolConfigurator.sol';
import { IERC20Detailed } from '../dependencies/interfaces/IERC20Detailed.sol';
import { IACLManager } from '../dependencies/interfaces/IACLManager.sol';
import { IPool } from '../dependencies/interfaces/IPool.sol';
import { IERC20 } from '../dependencies/IERC20.sol';
import { SafeERC20 } from '../dependencies/SafeERC20.sol';

/// @title ListingConfigEngine
/// @author HyperLend
/// @notice Config engine used to list new tokens
/// @dev New contract has to be deployed per proposal
contract ListingConfigEngine is Ownable {
    using SafeERC20 for IERC20;

    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                         Structs                          */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

    /// @notice struct holding all information about the proposal
    struct Proposal {
        uint256 proposalId;             // proposal ID
        MarketConfig marketConfig;      // info about the market we want to add the asset to
        AssetConfig assetConfig;        // info about the asset we want to add
    }

    /// @notice info about the market we want to add the asset to
    struct MarketConfig {
        address priceSource;            // external chainlink-compatible price source contract
        address poolAddressesProvider;  // poolAddressesProvider of the market
    }

    /// @notice info about the asset we want to add
    struct AssetConfig {
        address underlyingAsset;              // address of the underlying asset
        address aTokenImpl;                   // address of the hToken implementation contract
        address stableDebtTokenImpl;          // address of the stable debt implementation contract
        address variableDebtTokenImpl;        // address of the variable debt implementation contract
        address interestRateStrategyAddress;  // address of the interest rate strategy contract
        address treasury;                     // address of the treasury
        address incentivesController;         // address of the incentives controler contract, can be address(0)
        ReserveConfig reserveConfig;          // info about the asset reserve configuration
    }

    /// @notice info about the asset reserve configuration
    struct ReserveConfig {
        uint256 baseLTV;               // loan-to-value ratio in bsp (8000 = 80%)
        uint256 liquidationThreshold;  // liquidation threshold in bps
        uint256 liquidationBonus;      // bonus paid to the liquidators, in bps, must be >100%, otherwise liquidator would receive less (11000 = 10%)
        uint256 reserveFactor;         // reserve factor of the interest paid to the treasury, in bps
        uint256 borrowCap;             // borrow cap, in full tokens (100 BTC = 100, not 100**decimals)
        uint256 supplyCap;             // supply cap, in full tokens
        bool stableBorrowingEnabled;   // is stable borrowing enabled
        bool borrowingEnabled;         // is borrowing enabled
        bool flashLoanEnabled;         // are flashloans enabled for this asset
        uint256 seedAmount;            // amount of the token, used to seed the pool, must be > 10000
        address seedAmountsHolder;     // contract used to hold seed amounts, can be address(0)
    }

    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                        Variables                         */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

    /// @notice info about the proposal
    Proposal public proposal;
    /// @notice signals if the proposal was already executed
    bool public isExecuted;
    
    /// @notice pool address provider of the market
    IPoolAddressesProvider public poolAddressesProvider;
    /// @notice pool configurator of the market
    IPoolConfigurator public poolConfigurator;

    /// @dev strings are stored separately, since they are causing problems if they are encoded in the struct
    /// @notice description of the proposal
    string public description;   
    /// @notice prefix used in the hToken name    
    string public hTokenNamePrefix;
    /// @notice prefix used in the hToken symbol
    string public symbolPrefix;
    /// @notice prefix used for debt tokens name
    string public debtTokenPrefix;

    /// @notice event emitting the price source data, used during simulations
    event PriceSourceData(uint256 _price);

    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                     Admin functions                      */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

    /// @notice constructor that receives abi encoded proposal and string prefixes
    /// @param _encodedProposal abi encoded proposal
    /// @param _desc description of the proposal
    /// @param _hTokenNamePrefix prefix used in the hToken name
    /// @param _symbolPrefix prefix used in the hToken symbol
    /// @param _debtTokenPrefix prefix used for debt tokens name
    constructor(bytes memory _encodedProposal, string memory _desc, string memory _hTokenNamePrefix, string memory _symbolPrefix, string memory _debtTokenPrefix) {
        proposal = abi.decode(_encodedProposal, (Proposal));

        description = _desc;
        hTokenNamePrefix = _hTokenNamePrefix;
        symbolPrefix = _symbolPrefix;
        debtTokenPrefix = _debtTokenPrefix;

        poolAddressesProvider = IPoolAddressesProvider(proposal.marketConfig.poolAddressesProvider);
        poolConfigurator = IPoolConfigurator(poolAddressesProvider.getPoolConfigurator());
    }

    /// @notice function used to execute the proposal
    function executeProposal() external onlyOwner() {
        _beforeProposal();

        _configureOracle();
        _initReserve();
        _configureReserve();

        _afterProposal();
    }

    /// @notice function used to cancel the proposal
    function cancelProposal() external onlyOwner() {
        _afterProposal();
    }


    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                    Internal functions                    */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


    /// @notice checks if the proposal was not yet executed and the contract has all required privilegies
    function _beforeProposal() internal view {
        require(!isExecuted, "alreadyExecuted");

        //verify we have all correct privilegies on ACLManager
        IACLManager aclManager = IACLManager(poolAddressesProvider.getACLManager());
        require(aclManager.isAssetListingAdmin(address(this)), "missing assetListingAdmin privilegies");
        require(aclManager.isRiskAdmin(address(this)), "missing riskAdmin privilegies");
    }

    /// @notice marks proposal as executed
    function _afterProposal() internal {
        isExecuted = true;
    }

    /// @notice adds the new price source to the market oracle
    function _configureOracle() internal {
        MarketConfig memory marketConfig = proposal.marketConfig;
        AssetConfig memory assetConfig = proposal.assetConfig;

        //get addresses from the addressesProvider
        IOracle oracle = IOracle(poolAddressesProvider.getPriceOracle());

        //verify the price source exists on the external aggregator
        uint256 sourcePrice = uint256(IPriceSource(marketConfig.priceSource).latestAnswer());
        require(sourcePrice != 0, "price == 0");
        emit PriceSourceData(sourcePrice); 

        //check if the decimals from the price source match the base currency unit
        //in case of USD price feeds, BASE_CURRENCY_UNIT = 100000000 and decimals() = 8
        uint256 priceSourceDecimals = IPriceSource(marketConfig.priceSource).decimals();
        uint256 baseCurrencyUnit = oracle.BASE_CURRENCY_UNIT();
        require(baseCurrencyUnit / 10**priceSourceDecimals == 1, "BASE_CURRENCY_UNIT and priceSourceDecimals mismatch");

        //add asset to oracle
        address[] memory assets = new address[](1);
        assets[0] = assetConfig.underlyingAsset;
        address[] memory sources = new address[](1);
        sources[0] = address(marketConfig.priceSource);
        oracle.setAssetSources(assets, sources);

        //verify oracle response is correct
        uint256 oraclePrice = oracle.getAssetPrice(assetConfig.underlyingAsset);
        require(oraclePrice == sourcePrice, "oraclePrice != sourcePrice");
    }

    /// @notice initializes the reserve for the asset using PoolConfigurator
    function _initReserve() internal {
        AssetConfig memory assetConfig = proposal.assetConfig;

        string memory symbol = IERC20Detailed(assetConfig.underlyingAsset).symbol();

        ConfiguratorInputTypes.InitReserveInput[] memory initInputConfig = new ConfiguratorInputTypes.InitReserveInput[](1);
        initInputConfig[0] = ConfiguratorInputTypes.InitReserveInput({
            aTokenImpl: assetConfig.aTokenImpl,
            stableDebtTokenImpl: assetConfig.stableDebtTokenImpl,
            variableDebtTokenImpl: assetConfig.variableDebtTokenImpl,
            underlyingAssetDecimals: IERC20Detailed(assetConfig.underlyingAsset).decimals(),
            interestRateStrategyAddress: assetConfig.interestRateStrategyAddress,
            underlyingAsset: assetConfig.underlyingAsset,
            treasury: assetConfig.treasury,
            incentivesController: assetConfig.incentivesController,
            aTokenName: string(abi.encodePacked("HyperLend ", hTokenNamePrefix, " ", symbol)),
            aTokenSymbol: string(abi.encodePacked("h", symbolPrefix, symbol)),
            variableDebtTokenName: string(abi.encodePacked("HyperLend ", debtTokenPrefix, " Variable Debt ", symbol)),
            variableDebtTokenSymbol: string(abi.encodePacked("hVariableDebt", symbolPrefix, symbol)),
            stableDebtTokenName: string(abi.encodePacked("HyperLend ", debtTokenPrefix, " Stable Debt ", symbol)),
            stableDebtTokenSymbol: string(abi.encodePacked("hStableDebt", symbolPrefix, symbol)),
            params: "0x10"
        });
        poolConfigurator.initReserves(initInputConfig);
    }

    /// @notice configures the reserve for the asset using ReservesSetupHelper
    function _configureReserve() internal {
        AssetConfig memory assetConfig = proposal.assetConfig;
        ReserveConfig memory reserveConfig = proposal.assetConfig.reserveConfig;
  
        poolConfigurator.configureReserveAsCollateral(
            assetConfig.underlyingAsset,
            reserveConfig.baseLTV,
            reserveConfig.liquidationThreshold,
            reserveConfig.liquidationBonus
        );

        if (reserveConfig.borrowingEnabled) {
            poolConfigurator.setReserveBorrowing(assetConfig.underlyingAsset, true);

            poolConfigurator.setBorrowCap(assetConfig.underlyingAsset, reserveConfig.borrowCap);
            poolConfigurator.setReserveStableRateBorrowing(
                assetConfig.underlyingAsset,
                reserveConfig.stableBorrowingEnabled
            );
        }

        poolConfigurator.setReserveFlashLoaning(
            assetConfig.underlyingAsset,
            reserveConfig.flashLoanEnabled
        );
        poolConfigurator.setSupplyCap(assetConfig.underlyingAsset, reserveConfig.supplyCap);
        poolConfigurator.setReserveFactor(assetConfig.underlyingAsset, reserveConfig.reserveFactor);   

        _seedPool(assetConfig.underlyingAsset, poolAddressesProvider.getPool(), reserveConfig.seedAmount, reserveConfig.seedAmountsHolder);  
    }

    /// @notice function used to seed the new pool, so it's never empty
    function _seedPool(address token, address pool, uint256 amount, address seedAmountsHolder) internal {
        require(amount >= 10000, 'seed amount too low');

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).safeIncreaseAllowance(pool, amount);
        IPool(pool).supply(token, amount, seedAmountsHolder, 0);
    }

    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                      View functions                      */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

    /// @notice returns the proposal struct
    function getProposal() external view returns (Proposal memory _proposal){
        return proposal;
    }

    /// @notice returns the market config struct
    function getMarketConfig() external view returns (MarketConfig memory _marketConfig){
        return proposal.marketConfig;
    }

    /// @notice returns the asset config struct
    function getAssetConfig() external view returns (AssetConfig memory _assetConfig){
        return proposal.assetConfig;
    }

    /// @notice returns the reserveConfig struct
    function getReserveConfig() external view returns (ReserveConfig memory _reserveConfig){
        return proposal.assetConfig.reserveConfig;
    }

    /// @notice returns the string metadata of the proposal
    /// @return description description of the proposal
    /// @return hTokenNamePrefix prefix used in the hToken name   
    /// @return symbolPrefix prefix used in the hToken symbol
    /// @return debtTokenPrefix prefix used for debt tokens name
    function getMetadata() external view returns (string memory, string memory, string memory, string memory) {
        return (description, hTokenNamePrefix, symbolPrefix, debtTokenPrefix);
    }
}