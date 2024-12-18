const { encodeCapConfigProposal } = require("../../utils/encode")

async function main() {
    let proposal = {
        proposalId: "1",
        description: "Increase WETH market supply cap to 10,000 WETH",
        poolAddressesProvider: "0xa1d0ca19d6877cE4Bf51496305393aa28607012d",
        asset: "0xe0bdd7e8b7bf5b15dcDA6103FCbBA82a460ae2C7",
        newCap: "10000",
        actionType: "0"
    }
    let encodedProposal = await encodeCapConfigProposal(proposal)

    const CapsConfigEngine = await ethers.getContractFactory("CapsConfigEngine")
    const capsConfiguratorEngine = await CapsConfigEngine.deploy(
        encodedProposal, proposal.description, 
    )
    console.log(`capsConfiguratorEngine deployed to: ${capsConfiguratorEngine.target}`)
    console.log(`proposal:`, await capsConfiguratorEngine.getProposal())
    console.log(`metadata:`, await capsConfiguratorEngine.getMetadata())
}
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});