// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { ListingConfigEngine } from './ListingConfigEngine.sol';
import { Ownable } from './dependencies/Ownable.sol';
import { IERC20Detailed } from './dependencies/interfaces/IERC20Detailed.sol';

/// @title ConfigEngineFactory
/// @author HyperLend
/// @notice Config engine factory used to create instances of ListingConfigEngine
contract ConfigEngineFactory is Ownable {
    /// @notice number of the proposals
    uint256 public lastProposalId;
    /// @notice mapping between id and instances of ListingConfigEngine
    mapping(uint256 => address) public proposalConfigEngines;

    /// @notice event emmited when proposal is created
    event ProposalCreated(uint256 _id);
    /// @notice event emmited when proposal is executed
    event ProposalExecuted(uint256 _id);
    /// @notice event emmited when proposal is canceled
    event ProposalCanceled(uint256 _id);

    constructor() {}

    /// @notice function used to create new instances of the ListingConfigEngine
    /// @param _encodedProposal abi encoded proposal
    /// @param _desc description of the proposal
    /// @param _hTokenNamePrefix prefix used in the hToken name
    /// @param _symbolPrefix prefix used in the hToken symbol
    /// @param _debtTokenPrefix prefix used for debt tokens name
    function createProposal(
        bytes memory _encodedProposal, 
        string memory _desc, 
        string memory _hTokenNamePrefix, 
        string memory _symbolPrefix, 
        string memory _debtTokenPrefix
    ) external onlyOwner() {
        ListingConfigEngine listingConfigEngine = new ListingConfigEngine(
            _encodedProposal,
            _desc,
            _hTokenNamePrefix,
            _symbolPrefix,
            _debtTokenPrefix
        );

        // approve the underlying token, so new pool can be seeded
        IERC20Detailed underlyingToken = IERC20Detailed(listingConfigEngine.getAssetConfig().underlyingAsset);
        underlyingToken.approve(address(listingConfigEngine), listingConfigEngine.getReserveConfig().seedAmount);

        proposalConfigEngines[lastProposalId] = address(listingConfigEngine);
        lastProposalId++;

        emit ProposalCreated(lastProposalId);
    }

    /// @notice function used to execute certain proposal
    function executeProposal(uint256 _id) external onlyOwner() {
        ListingConfigEngine(proposalConfigEngines[_id]).executeProposal();
        emit ProposalExecuted(_id);
    }

    /// @notice function used to cancel a certain proposal
    function cancelProposal(uint256 _id) external onlyOwner() {
        ListingConfigEngine(proposalConfigEngines[_id]).cancelProposal();
        emit ProposalCanceled(_id);
    }

    /// @notice returns the proposal info by id
    function getProposal(uint256 _id) external view returns (ListingConfigEngine.Proposal memory _proposal) {
        return ListingConfigEngine(proposalConfigEngines[_id]).getProposal();
    }

    /// @notice returns the proposal description
    function getDescription(uint256 _id) external view returns (string memory _desc) {
        return ListingConfigEngine(proposalConfigEngines[_id]).description();
    }
}
