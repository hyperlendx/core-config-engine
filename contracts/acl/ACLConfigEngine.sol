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

/// @title ACLConfigEngine
/// @author HyperLend
/// @notice Config engine used to update ACL Manager
/// @dev New contract has to be deployed per proposal
contract ACLConfigEngine is Ownable {
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
    /*                     Structs & Enums                      */
    /*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

    /// @notice enum mapping the function names to IDs
    enum ActionType {
        ADD_POOL_ADMIN, 
        REMOVE_POOL_ADMIN,
        ADD_EMERGENCY_ADMIN, 
        REMOVE_EMERGENCY_ADMIN,
        ADD_RISK_ADMIN,
        REMOVE_RISK_ADMIN,
        ADD_FLASH_BORROWER,
        REMOVE_FLASH_BORROWER,
        ADD_BRIDGE,
        REMOVE_BRIDGE,
        ADD_ASSET_LISTING_ADMIN,
        REMOVE_ASSET_LISTING_ADMIN
    }

    /// @notice struct holding all information about the proposal
    struct Proposal {
        uint256 proposalId;               // proposal ID
        address poolAddressesProvider;    // pool addresses provider of the market
        address admin;                    // address to receive or lose role
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
    /// @notice ACL manager of the market
    IACLManager public aclManager;

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
        aclManager = IACLManager(poolAddressesProvider.getACLManager());
    }

    /// @notice function used to execute the proposal
    function executeProposal() external onlyOwner() {
        _beforeProposal();

        _setAclManagerConfig();

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
    }

    /// @notice marks proposal as executed
    function _afterProposal() internal {
        isExecuted = true;
    }

    /// @notice updates the ACLManager configuration
    function _setAclManagerConfig() internal {
        if (proposal.actionType == ActionType.ADD_POOL_ADMIN){
            aclManager.addPoolAdmin(proposal.admin);
        }

        if (proposal.actionType == ActionType.REMOVE_POOL_ADMIN){
            aclManager.removePoolAdmin(proposal.admin);
        }

        if (proposal.actionType == ActionType.ADD_EMERGENCY_ADMIN){
            aclManager.addEmergencyAdmin(proposal.admin);
        }

        if (proposal.actionType == ActionType.REMOVE_EMERGENCY_ADMIN){
            aclManager.removeEmergencyAdmin(proposal.admin);
        }

        if (proposal.actionType == ActionType.ADD_RISK_ADMIN){
            aclManager.addRiskAdmin(proposal.admin);
        }

        if (proposal.actionType == ActionType.REMOVE_RISK_ADMIN){
            aclManager.removeRiskAdmin(proposal.admin);
        }

        if (proposal.actionType == ActionType.ADD_FLASH_BORROWER){
            aclManager.addFlashBorrower(proposal.admin);
        }

        if (proposal.actionType == ActionType.REMOVE_FLASH_BORROWER){
            aclManager.removeFlashBorrower(proposal.admin);
        }

        if (proposal.actionType == ActionType.ADD_BRIDGE){
            aclManager.addBridge(proposal.admin);
        }

        if (proposal.actionType == ActionType.REMOVE_BRIDGE){
            aclManager.removeBridge(proposal.admin);
        }

        if (proposal.actionType == ActionType.ADD_ASSET_LISTING_ADMIN){
            aclManager.addAssetListingAdmin(proposal.admin);
        }

        if (proposal.actionType == ActionType.REMOVE_ASSET_LISTING_ADMIN){
            aclManager.removeAssetListingAdmin(proposal.admin);
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