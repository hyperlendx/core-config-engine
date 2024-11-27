async function encodeCapConfigProposal(proposal){
    const abiEncoder = new ethers.AbiCoder()

    const proposalStructTypes = [
        "uint256", //id
        "address", //poolAddressesProvider
        "address", //asset
        "uint256", //enwCap
        "uint256", //actionType
    ]

    return abiEncoder.encode(
        proposalStructTypes,
        [
            proposal.proposalId,
            proposal.poolAddressesProvider,
            proposal.asset,
            proposal.newCap,
            proposal.actionType
        ]
    );
}

async function encodeListingProposal(proposal){
    const abiEncoder = new ethers.AbiCoder()

    const reserveConfigTuple = `tuple(uint256, uint256, uint256, uint256, uint256, uint256, bool, bool, bool, uint256, address)`
    const proposalStructTypes = [
        "uint256", //id
        "tuple(address, address)", //market config
        `tuple(address, address, address, address, address, address, address, ${reserveConfigTuple})` //assets config
    ]

    return abiEncoder.encode(
        proposalStructTypes,
        [
            proposal.proposalId,
            [
                proposal.marketConfig.priceSource,
                proposal.marketConfig.poolAddressesProvider
            ],
            [
                proposal.assetConfig.underlyingAsset,
                proposal.assetConfig.aTokenImpl,
                proposal.assetConfig.stableDebtTokenImpl,
                proposal.assetConfig.variableDebtTokenImpl,
                proposal.assetConfig.interestRateStrategyAddress,
                proposal.assetConfig.treasury,
                proposal.assetConfig.incentivesController,
                [
                    proposal.assetConfig.reserveConfig.baseLTV,
                    proposal.assetConfig.reserveConfig.liquidationThreshold,
                    proposal.assetConfig.reserveConfig.liquidationBonus,
                    proposal.assetConfig.reserveConfig.reserveFactor,
                    proposal.assetConfig.reserveConfig.borrowCap,
                    proposal.assetConfig.reserveConfig.supplyCap,
                    proposal.assetConfig.reserveConfig.stableBorrowingEnabled,
                    proposal.assetConfig.reserveConfig.borrowingEnabled,
                    proposal.assetConfig.reserveConfig.flashLoanEnabled,
                    proposal.assetConfig.reserveConfig.seedAmount,
                    proposal.assetConfig.reserveConfig.seedAmountsHolder
                ]
            ]
        ]
    );
}

async function encodeACLConfigProposal(proposal){
    const abiEncoder = new ethers.AbiCoder()

    const proposalStructTypes = [
        "uint256", //id
        "address", //poolAddressesProvider
        "address", //admin
        "uint256", //actionType
    ]

    return abiEncoder.encode(
        proposalStructTypes,
        [
            proposal.proposalId,
            proposal.poolAddressesProvider,
            proposal.admin,
            proposal.actionType
        ]
    );
}

module.exports = {
    encodeCapConfigProposal: encodeCapConfigProposal,
    encodeListingProposal: encodeListingProposal,
    encodeACLConfigProposal: encodeACLConfigProposal
}