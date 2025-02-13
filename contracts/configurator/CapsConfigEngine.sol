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

/// @title CapsConfigEngine
/// @author HyperLend
/// @notice Configurator engine, used to change protocol supply and borrow caps
/// @dev New contract has to be deployed per proposal
contract CapsConfigEngine is Ownable {
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                     Structs & Enums                      */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

    /// @notice enum mapping the function names to IDs
    enum ActionType {
        SET_SUPPLY_CAP,
        SET_BORROW_CAP
    }

    /// @notice struct holding all information about the proposal
    struct Proposal {
        uint256 proposalId;               // proposal ID
        address poolAddressesProvider;    // pool addresses provider of the market
        address asset;                    // address of the asset to be updated
        uint256 newCap;                   // new supply or borrow cap of the reserve
        ActionType actionType;            // type of the action to be done
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

    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                     Admin functions                      */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

    /// @notice constructor that receives abi encoded proposal and string prefixes
    /// @param _encodedProposal abi encoded proposal
    /// @param _desc description of the proposal
    constructor(bytes memory _encodedProposal, string memory _desc) {
        proposal = abi.decode(_encodedProposal, (Proposal));

        description = _desc;
      
        poolAddressesProvider = IPoolAddressesProvider(proposal.poolAddressesProvider);
        poolConfigurator = IPoolConfigurator(poolAddressesProvider.getPoolConfigurator());
    }

    /// @notice function used to execute the proposal
    function executeProposal() external onlyOwner() {
        _beforeProposal();

        _execute();

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
        require(aclManager.isRiskAdmin(address(this)), "missing riskAdmin privilegies");
    }

    /// @notice marks proposal as executed
    function _afterProposal() internal {
        isExecuted = true;
    }

    /// @notice updates the reserve caps
    function _execute() internal {        
        if (proposal.actionType == ActionType.SET_SUPPLY_CAP){
            poolConfigurator.setSupplyCap(proposal.asset, proposal.newCap);
        }

        if (proposal.actionType == ActionType.SET_BORROW_CAP){
            poolConfigurator.setBorrowCap(proposal.asset, proposal.newCap);
        }
    }

    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                      View functions                      */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

    /// @notice returns the proposal struct
    function getProposal() external view returns (Proposal memory _proposal){
        return proposal;
    }

    /// @notice returns the string metadata of the proposal
    /// @return description description of the proposal
    function getMetadata() external view returns (string memory) {
        return (description);
    }
}