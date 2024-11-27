async function main() {
    const [signer] = await ethers.getSigners();

    let proposal = {
        proposalId: "1",
        description: "Increase WETH market supply cap to 10,000 WETH",
        poolAddressesProvider: "0xa1d0ca19d6877cE4Bf51496305393aa28607012d",
        asset: "0xe0bdd7e8b7bf5b15dcDA6103FCbBA82a460ae2C7",
        newCap: "10000",
        actionType: "0"
    }

    let encodedProposal = await encode(proposal)

    const CapsConfigEngine = await ethers.getContractFactory("CapsConfigEngine")
    const capsConfiguratorEngine = await CapsConfigEngine.deploy(
        encodedProposal, proposal.description, 
    )
    console.log(`capsConfiguratorEngine deployed to: ${capsConfiguratorEngine.target}`)

    const poolAddressesProvider = await ethers.getContractAt("IPoolAddressesProvider", proposal.poolAddressesProvider);
    const aclManager = await ethers.getContractAt("IACLManager", (await poolAddressesProvider.getACLManager()));

    console.log(await capsConfiguratorEngine.getProposal())
    console.log(await capsConfiguratorEngine.getMetadata())

    const sendTxAddRiskAdmin = await aclManager.addRiskAdmin(capsConfiguratorEngine.target)
    await sendTxAddRiskAdmin.wait()
    console.log(`risk admin added`)

    const sendTxExecute = await capsConfiguratorEngine.executeProposal();
    await sendTxExecute.wait()
    console.log(`proposal executed`)

    const sendTxRemoveRiskAdmin = await aclManager.removeRiskAdmin(capsConfiguratorEngine.target)
    await sendTxRemoveRiskAdmin.wait()
    console.log(`risk admin removed`)
}

async function encode(proposal){
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
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});