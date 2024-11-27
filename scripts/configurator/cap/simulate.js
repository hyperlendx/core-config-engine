const { encodeCapConfigProposal } = require("../../utils/encode")

const PROPOSAL_CONFIG_ENGINE_CONTRACT = ""

async function main() {
    const provider = ethers.provider;
    const [signer] = await ethers.getSigners();

    await provider.send("hardhat_setBalance", [ signer.address, `0x${Number(ethers.parseEther("100")).toString(16)}` ]);
    console.log("Forked at block number:", await provider.getBlockNumber());

    const configEngine = await ethers.getContractAt("CapsConfigEngine", PROPOSAL_CONFIG_ENGINE_CONTRACT);
    const proposal = await configEngine.getProposal();
    const poolAddressesProviderAddress = proposal[1]
    const asset = proposal[2]

    const poolAddressesProvider = await ethers.getContractAt("IPoolAddressesProvider", poolAddressesProviderAddress, signer);
    const aclManager = await ethers.getContractAt("IACLManager", (await poolAddressesProvider.getACLManager()), signer); 

    //impersonate acl admin
    const aclAdmin = await poolAddressesProvider.getACLAdmin();
    await provider.send("hardhat_impersonateAccount", [aclAdmin]);
    const aclAdminSigner = await ethers.getSigner(aclAdmin);

    //make configEngine riskAdmin
    await aclManager.connect(aclAdminSigner).addRiskAdmin(configEngine.target)
    console.log(`prepared privilegies`)

    //do simulations
    const execute = await configEngine.connect(signer).executeProposal();
    console.log(execute)

    //check if the token was added to the market
    const poolAddress = await poolAddressesProvider.getPool()
    const pool = await ethers.getContractAt("IPool", poolAddress, signer);
    const reserveData = await pool.getReserveData(asset)
    console.log(reserveData)
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
  