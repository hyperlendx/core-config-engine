// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IPoolConfigurator } from './IPoolConfigurator.sol';

interface IReservesSetupHelper {
    struct ConfigureReserveInput {
        address asset;
        uint256 baseLTV;
        uint256 liquidationThreshold;
        uint256 liquidationBonus;
        uint256 reserveFactor;
        uint256 borrowCap;
        uint256 supplyCap;
        bool stableBorrowingEnabled;
        bool borrowingEnabled;
        bool flashLoanEnabled;
    }

    /**
     * @notice External function called by the owner account to setup the assets risk parameters in batch.
     * @dev The Pool or Risk admin must transfer the ownership to ReservesSetupHelper before calling this function
     * @param configurator The address of PoolConfigurator contract
     * @param inputParams An array of ConfigureReserveInput struct that contains the assets and their risk parameters
     * @param pool The address of the Pool
     * @param seedAmounts Amount of the asset to supply
     */
    function configureReserves(
        IPoolConfigurator configurator,
        ConfigureReserveInput[] calldata inputParams,
        uint256[] calldata seedAmounts,
        address pool,
        address seedAmountsHolder
    ) external;

    function transferOwnership(address _newOwner) external;
}