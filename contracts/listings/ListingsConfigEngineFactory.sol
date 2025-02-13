// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ListingConfigEngine } from './ListingConfigEngine.sol';

import { Ownable } from '../dependencies/Ownable.sol';
import { IERC20Detailed } from '../dependencies/interfaces/IERC20Detailed.sol';
import { IERC20 } from '../dependencies/IERC20.sol';
import { SafeERC20 } from '../dependencies/SafeERC20.sol';

/// @title ListingsConfigEngineFactory
/// @author HyperLend
/// @notice Config engine factory used to create instances of ListingConfigEngine
contract ListingsConfigEngineFactory is Ownable {
    using SafeERC20 for IERC20;

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
        IERC20 underlyingToken = IERC20(listingConfigEngine.getAssetConfig().underlyingAsset);
        underlyingToken.safeIncreaseAllowance(address(listingConfigEngine), listingConfigEngine.getReserveConfig().seedAmount);

        proposalConfigEngines[lastProposalId] = address(listingConfigEngine);
        emit ProposalCreated(lastProposalId);

        lastProposalId++;
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

        //refund seed token balance
        IERC20 underlyingToken = IERC20(ListingConfigEngine(proposalConfigEngines[_id]).getAssetConfig().underlyingAsset);
        underlyingToken.safeTransfer(msg.sender, underlyingToken.balanceOf(address(this)));
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
