async function main() {
    const [signer] = await ethers.getSigners();

    let proposal = {
        proposalId: "1",
        description: "add WETH-2 to core market",
        marketConfig: {
            priceSource: "0xc88F13B22443E6dDe99bc702F0130A8edee45174",
            poolAddressesProvider: "0xa1d0ca19d6877cE4Bf51496305393aa28607012d",
        },
        assetConfig: {
            underlyingAsset: "0xADcb2f358Eae6492F61A5F87eb8893d09391d160",
            aTokenImpl: "0x7d028b7b61eA887FC942f1b5cb8245d6f1189582",
            stableDebtTokenImpl: "0x0a78cBB3123782AD75F8fA1faB566bA7eba76fd5",
            variableDebtTokenImpl: "0xF997DeA692C2D93359828321C5B711B791bBd46A",
            interestRateStrategyAddress: "0xFf377dbB97c674Bfa201d8CdcAe597D1231317Ea",
            treasury: "0x16703F774Bd7b2F2E6f39E7dCead924fa2080a0D",
            incentivesController: "0x0000000000000000000000000000000000000000",
            reserveConfig: {
                baseLTV: BigInt(6000),
                liquidationThreshold: BigInt(7500),
                liquidationBonus: BigInt(11000),
                reserveFactor: BigInt(2000),
                borrowCap: BigInt(0),
                supplyCap: BigInt(1000),
                stableBorrowingEnabled: false,
                borrowingEnabled: true,
                flashLoanEnabled: true,
                seedAmount: BigInt(100000),
                seedAmountsHolder: "0x64D06838d6EF45CCf4B082c55c892C088DacF4F7"
            }
        }
    }
    const prefixes = {
        hTokenNamePrefix: "HyperEVM Testnet",
        symbolPrefix: "HyperEvmTest",
        debtTokenPrefix: "HyperEVM Testnet",
    }
    let encodedProposal = await encode(proposal)

    const factory = await ethers.getContractAt("ConfigEngineFactory", "0x4ed9d9b47E464195ffa82aD614Cb5ecE5E1389d3", signer);

    let create = await factory.createProposal(
        encodedProposal, proposal.description, 
        prefixes.hTokenNamePrefix, prefixes.symbolPrefix, prefixes.debtTokenPrefix
    )
    console.log(create)
}

async function encode(proposal){
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
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});