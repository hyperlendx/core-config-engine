async function main() {
    const [signer] = await ethers.getSigners();

    const PROPOSAL_CONTRACT = "0x745FE617586D9f94C1A49ABa103DBfC432F0EE5f"
    const configEngine = await ethers.getContractAt("ListingConfigEngine", PROPOSAL_CONTRACT);

    // const wHYPE = await ethers.getContractAt("IERC20Detailed", "0x68CD2D3503cB4A334522E557c5BA1a0d5Fe56bfC")

    // //mint stHYPE tokens
    // console.log(await signer.sendTransaction({
    //   to: wHYPE.target,
    //   value: ethers.parseEther("1.0"), // Sends exactly 1.0 ether
    // }))
    // await wHYPE.approve(PROPOSAL_CONTRACT, "100000")

    //add asset listings privilegies
    const aclManager = await ethers.getContractAt("IACLManager", "0x52988EddD859b142b8AfbC3525852DE2B1b93F01"); 
    await aclManager.addRiskAdmin(configEngine.target)
    await aclManager.addAssetListingAdmin(configEngine.target)
    console.log(`prepared privilegies`)

    //execute proposal
    await configEngine.executeProposal()

    //remove configEngine from riskAdmin
    await aclManager.removeRiskAdmin(configEngine.target)
    await aclManager.removeAssetListingAdmin(configEngine.target)
    console.log(`removed privilegies`)

    const pool = await ethers.getContractAt("IPool", "0x1e85CCDf0D098a9f55b82F3E35013Eda235C8BD8");
    let reserveData = await pool.getReserveData("0x68CD2D3503cB4A334522E557c5BA1a0d5Fe56bfC")
    console.log(reserveData)
    const hToken = await ethers.getContractAt("IERC20Detailed", reserveData[8], signer);
    console.log(`hToken supply`, await hToken.totalSupply())
}
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});