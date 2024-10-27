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

// ConfigEngine must be riskAdmin and assetListingAdmin
contract ConfigEngine is Ownable {
    struct Proposal {
        uint256 proposalId;
        string name;
        string description;

        MarketConfig marketConfig;
        AssetConfig assetConfig;
    }

    struct MarketConfig {
        IPriceSource priceSource;
        IPoolAddressesProvider poolAddressesProvider;
        IReservesSetupHelper reservesSetupHelper;
    }

    struct AssetConfig {
        address underlyingAsset;
        address aTokenImpl;
        address stableDebtTokenImpl;
        address variableDebtTokenImpl;
        address interestRateStrategyAddress;
        address treasury;
        address incentivesController;
        string ATokenNamePrefix;
        string SymbolPrefix;
        string VariableDebtTokenNamePrefix;
        string StableDebtTokenNamePrefix;
        ReserveConfig reserveConfig;
    }

    struct ReserveConfig {
        uint256 baseLTV;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 reserveFactor;
        uint256 borrowCap;
        uint256 supplyCap;
        bool stableBorrowingEnabled;
        bool borrowingEnabled;
        bool flashLoanEnabled;
        uint256[] seedAmounts;
        address seedAmounsHolder;
    }

    Proposal public proposal;

    event PriceSourceData(uint256 _price);

    constructor(bytes memory _encodedProposal){
        proposal = abi.decode(_encodedProposal, (Proposal));
    }

    function executeProposal() external onlyOwner() {
        _configureOracle();
        _initReserves();
        _configureReserves();
    }

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

    function _initReserves() internal {
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

    function _configureReserves() internal {
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

        marketConfig.reservesSetupHelper.configureReserves(
            poolConfigurator,
            configureInputConfig,
            reserveConfig.seedAmounts,
            address(marketConfig.poolAddressesProvider.getPool()),
            reserveConfig.seedAmounsHolder
        );
        
        marketConfig.reservesSetupHelper.transferOwnership(owner()); //transfer ownership back to the pool admin
    }
}
