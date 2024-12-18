const { encodeListingProposal } = require("../utils/encode")

async function main() {
    let proposal = {
        proposalId: "3",
        description: "Add Wrapped HYPE",
        marketConfig: {
            priceSource: "0x38a8bCdD96477800e48c73eF55d95D3bDEd9cF3b",
            poolAddressesProvider: "0xa1d0ca19d6877cE4Bf51496305393aa28607012d",
        },
        assetConfig: {
            underlyingAsset: "0x68CD2D3503cB4A334522E557c5BA1a0d5Fe56bfC",
            aTokenImpl: "0x7d028b7b61eA887FC942f1b5cb8245d6f1189582",
            stableDebtTokenImpl: "0x0a78cBB3123782AD75F8fA1faB566bA7eba76fd5",
            variableDebtTokenImpl: "0xF997DeA692C2D93359828321C5B711B791bBd46A",
            interestRateStrategyAddress: "0xFf377dbB97c674Bfa201d8CdcAe597D1231317Ea",
            treasury: "0x16703F774Bd7b2F2E6f39E7dCead924fa2080a0D",
            incentivesController: "0x0000000000000000000000000000000000000000",
            reserveConfig: {
                baseLTV: BigInt(5000),
                liquidationThreshold: BigInt(6500),
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
    let encodedProposal = await encodeListingProposal(proposal)

    const ListingsConfigEngine = await ethers.getContractFactory("contracts/listings/ListingConfigEngine.sol:ListingConfigEngine");
    const configEngine = await ListingsConfigEngine.deploy(
        encodedProposal, proposal.description, 
        prefixes.hTokenNamePrefix, prefixes.symbolPrefix, prefixes.debtTokenPrefix
    )
    console.log(`ListingsConfigEnginde deployed to ${configEngine.target}`)
}
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});