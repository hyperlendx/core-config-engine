async function main() {
    const provider = ethers.provider;
    const [signer] = await ethers.getSigners();

    await provider.send("hardhat_setBalance", [ signer.address, `0x${Number(ethers.parseEther("100")).toString(16)}` ]);
    console.log("Forked at block number:", await provider.getBlockNumber());

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
                borrowCap: BigInt(1000),
                supplyCap: BigInt(0),
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

    const ListingsConfigEngine = await ethers.getContractFactory("ListingConfigEngine");
    const configEngine = await ListingsConfigEngine.deploy(
        encodedProposal, proposal.description, 
        prefixes.hTokenNamePrefix, prefixes.symbolPrefix, prefixes.debtTokenPrefix
    )
    console.log(`ListingsConfigEnginde deployed to ${configEngine.target}`)

    const poolAddressesProviderAddress = "0xa1d0ca19d6877cE4Bf51496305393aa28607012d"
    const poolAddressesProvider = await ethers.getContractAt("IPoolAddressesProvider", poolAddressesProviderAddress, signer);
    const aclManager = await ethers.getContractAt("IACLManager", (await poolAddressesProvider.getACLManager()), signer); 

    //transfer some tokens to the signer and approve configEgine to spend them
    const token = await ethers.getContractAt("IERC20Detailed", proposal.assetConfig.underlyingAsset, signer);
    await provider.send("hardhat_impersonateAccount", ['0x088D6D8ce1a3462ea91067329762Fd1e151B3142']);
    const tokensHolderSigner = await ethers.getSigner('0x088D6D8ce1a3462ea91067329762Fd1e151B3142');
    await token.connect(tokensHolderSigner).transfer(signer.address, "100000")
    await token.connect(signer).approve(configEngine.target, "100000")
    console.log(`Prepared tokens`)

    //impersonate acl admin
    const aclAdmin = await poolAddressesProvider.getACLAdmin();
    await provider.send("hardhat_impersonateAccount", [aclAdmin]);
    const aclAdminSigner = await ethers.getSigner(aclAdmin);

    //make configEngine riskAdmin
    await aclManager.connect(aclAdminSigner).addRiskAdmin(configEngine.target)
    //make configEngine listingsAdmin
    await aclManager.connect(aclAdminSigner).addAssetListingAdmin(configEngine.target)

    console.log(`prepared privilegies`)

    //do simulations & tests here
    let execute = await configEngine.connect(signer).executeProposal();
    console.log(execute)
    let r = await execute.wait()
    console.log(r)

    //remove configEngine from riskAdmin
    await aclManager.connect(aclAdminSigner).removeRiskAdmin(configEngine.target)
    //remove configEngine from listingsAdmin
    await aclManager.connect(aclAdminSigner).removeAssetListingAdmin(configEngine.target)

    console.log(`removed privilegies`)

    //check if the token was added to the market
    const poolAddress = await poolAddressesProvider.getPool()
    const pool = await ethers.getContractAt("IPool", poolAddress, signer);
    let reserveData = await pool.getReserveData(proposal.assetConfig.underlyingAsset)
    console.log(reserveData)
    const hToken = await ethers.getContractAt("IERC20Detailed", reserveData[8], signer);
    console.log(`hToken supply`, await hToken.totalSupply())
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
  