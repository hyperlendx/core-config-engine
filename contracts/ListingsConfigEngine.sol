// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { Ownable } from './dependencies/Ownable.sol';
import { ConfiguratorInputTypes } from './dependencies/types/ConfiguratorInputTypes.sol';

import { IOracle } from './dependencies/interfaces/IOracle.sol';
import { IPriceSource } from './dependencies/interfaces/IPriceSource.sol';
import { IPoolAddressesProvider } from './dependencies/interfaces/IPoolAddressesProvider.sol';
import { IPoolConfigurator } from './dependencies/interfaces/IPoolConfigurator.sol';
import { IERC20Detailed } from './dependencies/interfaces/IERC20Detailed.sol';
import { IReservesSetupHelper } from './dependencies/interfaces/IReservesSetupHelper.sol';
import { IACLManager } from './dependencies/interfaces/IACLManager.sol';


/// @title ListingsConfigEngine
/// @author HyperLend
/// @notice Config engine used to list new tokens
/// @dev New contract has to be deployed per proposal
contract ListingsConfigEngine is Ownable {
    /// @notice signals if the proposal was already executed
    bool public isExecuted;

    /// @notice struct holding all information about the proposal
    struct Proposal {
        uint256 proposalId;         // proposal ID
        string description;         // description of the proposal
        
        MarketConfig marketConfig;  // info about the market we want to add the asset to
        AssetConfig assetConfig;    // info about the asset we want to add
    }

    /// @notice info about the market we want to add the asset to
    struct MarketConfig {
        IPriceSource priceSource;                      // external chainlink-compatible price source contract
        IPoolAddressesProvider poolAddressesProvider;  // poolAddressesProvider of the market
        IReservesSetupHelper reservesSetupHelper;      // reservesSetupHelper helper contract
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
        string ATokenNamePrefix;              // prefix used in the hToken name
        string SymbolPrefix;                  // prefix used in the hToken symbol
        string VariableDebtTokenNamePrefix;   // prefix used for variable debt token name
        string StableDebtTokenNamePrefix;     // prefix used for stable debt token name
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
        address seedAmounsHolder;      // contract used to hold seed amounts, can be address(0)
    }

    /// @notice info about the proposal
    Proposal public proposal;

    /// @notice event emitting the price source data, used during simulations
    event PriceSourceData(uint256 _price);

    constructor(bytes memory _encodedProposal){
        proposal = abi.decode(_encodedProposal, (Proposal));
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

    /// @notice checks if the proposal was not yet executed and the contract has all required privilegies
    function _beforeProposal() internal {
        require(!isExecuted, "alreadyExecuted");

        //verify we have all correct privilegies on ACLManager
        IACLManager aclManager = IACLManager(proposal.marketConfig.poolAddressesProvider.getACLManager());
        require(aclManager.isAssetListingAdmin(address(this)), "missing assetListingAdmin privilegies");
        require(aclManager.isRiskAdmin(address(this)), "missing assetListingAdmin privilegies");

        //verify we are owner of ReservesSetupHelper
        require(IReservesSetupHelper(proposal.marketConfig.reservesSetupHelper).owner() == address(this), "missing ownership of reservesSetupHelper");
    }

    /// @notice marks proposal as executed and transfers ownership of reservesSetupHelper back to owner
    function _afterProposal() internal {
        isExecuted = true;
        proposal.marketConfig.reservesSetupHelper.transferOwnership(owner());
    }

    /// @notice adds the new price source to the market oracle
    function _configureOracle() internal {
        MarketConfig memory marketConfig = proposal.marketConfig;
        AssetConfig memory assetConfig = proposal.assetConfig;

        //get addresses from the addressesProvider
        IOracle oracle = IOracle(marketConfig.poolAddressesProvider.getPriceOracle());

        //verify the price source exists on the external aggregator
        uint256 sourcePrice = uint256(marketConfig.priceSource.latestAnswer());
        require(sourcePrice != 0, "price == 0");
        emit PriceSourceData(sourcePrice); 

        //add asset to oracle
        address[] memory assets;
        assets[0] = assetConfig.underlyingAsset;
        address[] memory sources;
        sources[0] = address(marketConfig.priceSource);
        oracle.setAssetSources(assets, sources);

        //verify oracle response is correct
        uint256 oraclePrice = oracle.getAssetPrice(assetConfig.underlyingAsset);
        require(oraclePrice == sourcePrice, "oraclePrice != sourcePrice");
    }

    /// @notice initializes the reserve for the asset using PoolConfigurator
    function _initReserve() internal {
        MarketConfig memory marketConfig = proposal.marketConfig;
        AssetConfig memory assetConfig = proposal.assetConfig;

        IPoolConfigurator poolConfigurator = IPoolConfigurator(marketConfig.poolAddressesProvider.getPoolConfigurator());
        string memory symbol = IERC20Detailed(assetConfig.underlyingAsset).symbol();

        ConfiguratorInputTypes.InitReserveInput[] memory initInputConfig;
        initInputConfig[0] = ConfiguratorInputTypes.InitReserveInput({
            aTokenImpl: assetConfig.aTokenImpl,
            stableDebtTokenImpl: assetConfig.stableDebtTokenImpl,
            variableDebtTokenImpl: assetConfig.variableDebtTokenImpl,
            underlyingAssetDecimals: IERC20Detailed(assetConfig.underlyingAsset).decimals(),
            interestRateStrategyAddress: assetConfig.interestRateStrategyAddress,
            underlyingAsset: assetConfig.underlyingAsset,
            treasury: assetConfig.treasury,
            incentivesController: assetConfig.incentivesController,
            aTokenName: string(abi.encodePacked("HyperLend ", assetConfig.ATokenNamePrefix, " ", symbol)),
            aTokenSymbol: string(abi.encodePacked("h", assetConfig.SymbolPrefix, symbol)),
            variableDebtTokenName: string(abi.encodePacked("HyperLend ", assetConfig.VariableDebtTokenNamePrefix, " Variable Debt ", symbol)),
            variableDebtTokenSymbol: string(abi.encodePacked("hVariableDebt", assetConfig.SymbolPrefix, symbol)),
            stableDebtTokenName: string(abi.encodePacked("HyperLend ", assetConfig.StableDebtTokenNamePrefix, " Stable Debt ", symbol)),
            stableDebtTokenSymbol: string(abi.encodePacked("hStableDebt", assetConfig.SymbolPrefix, symbol)),
            params: "0x10"
        });
        poolConfigurator.initReserves(initInputConfig);
    }

    /// @notice configures the reserve for the asset using ReservesSetupHelper
    function _configureReserve() internal {
        MarketConfig memory marketConfig = proposal.marketConfig;
        AssetConfig memory assetConfig = proposal.assetConfig;
        ReserveConfig memory reserveConfig = proposal.assetConfig.reserveConfig;

        IPoolConfigurator poolConfigurator = IPoolConfigurator(marketConfig.poolAddressesProvider.getPoolConfigurator());

        IReservesSetupHelper.ConfigureReserveInput[] memory configureInputConfig;
        configureInputConfig[0] = IReservesSetupHelper.ConfigureReserveInput({
            asset: assetConfig.underlyingAsset,
            baseLTV: reserveConfig.baseLTV,
            liquidationThreshold: reserveConfig.liquidationThreshold,
            liquidationBonus: reserveConfig.liquidationBonus,
            reserveFactor: reserveConfig.reserveFactor,
            borrowCap: reserveConfig.borrowCap,
            supplyCap: reserveConfig.supplyCap,
            stableBorrowingEnabled: reserveConfig.stableBorrowingEnabled,
            borrowingEnabled: reserveConfig.borrowingEnabled,
            flashLoanEnabled: reserveConfig.flashLoanEnabled
        });

        uint256[] memory seedAmounts;
        seedAmounts[0] = reserveConfig.seedAmount;

        marketConfig.reservesSetupHelper.configureReserves(
            poolConfigurator,
            configureInputConfig,
            seedAmounts,
            address(marketConfig.poolAddressesProvider.getPool()),
            reserveConfig.seedAmounsHolder
        );        
    }
}
