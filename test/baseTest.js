const { expect } = require("chai");
const { execSync } = require('child_process');
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

//compile and copy external contracts
console.log(`compiling imported contracts, this might take a while...`)
execSync(`cd ./node_modules/hyperlendcore/ && npx hardhat compile`, { stdio: 'inherit' })
execSync(`cp -r ./node_modules/hyperlendcore/artifacts ./artifacts/external`);

// see: https://github.com/hyperlendx/hyperlend-core/blob/master/test/utils/setup.js 
// see: https://github.com/hyperlendx/hyperlend-core/blob/master/test/baseTest.js for list of available methods and contractIDs
const { prepareEnv } = require("hyperlendcore/test/utils/setup.js")
const { encodeListingProposal } = require("../scripts/utils/encode")

describe("HyperLendCore", function () {
    async function prepareEnvFixture(){
        const [owner, user] = await ethers.getSigners();
        const env = await prepareEnv()

        await env.setupEnv()

        return { env, owner, user }
    }

    it("should deploy & configure & supply to the test env market", async function () {
        const { env, owner, user } = await loadFixture(prepareEnvFixture)

        const mockToken = await env.getContractInstanceById("mockERC20")
        const poolProxy = await env.getContractInstanceById("poolProxy")
        
        await mockToken.connect(owner).transfer(user.address, "1000000")
        await mockToken.connect(user).approve(poolProxy.target, "1000000")
        await poolProxy.connect(user).supply(mockToken.target, "1000000", user.address, "0")

        let aTokenAddress = (await poolProxy.getReserveData(mockToken.target))[8]
        let aToken = await env.getATokenInstance(aTokenAddress)

        expect(await poolProxy.getReservesList()).to.deep.equal([mockToken.target])
        expect(Number(await aToken.balanceOf(user.address))).to.equal(1000000)
    });

    it("should create and execute a proposal", async function () {
        const { env, owner } = await loadFixture(prepareEnvFixture)

        const newToken = await (await ethers.getContractFactory("MintableERC20")).deploy("MockToken2", "MOCK2", 18)
        
        let proposal = {
            proposalId: "1",
            description: "add MOCK2 to core market",
            marketConfig: {
                priceSource: ((await env.getAvailableContracts())["mockHyperEvmOracleProxy"]),
                poolAddressesProvider: (await env.getContractInstanceById("poolAddressesProvider")).target,
            },
            assetConfig: {
                underlyingAsset: newToken.target,
                aTokenImpl: (await env.getContractInstanceById("aToken")).target,
                stableDebtTokenImpl: (await env.getContractInstanceById("stableDebtToken")).target,
                variableDebtTokenImpl: (await env.getContractInstanceById("variableDebtToken")).target,
                interestRateStrategyAddress: ((await env.getAvailableContracts())["defaultReserveInterestRateStrategy"])[0],
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
                    seedAmountsHolder: "0x0000000000000000000000000000000000000000"
                }
            }
        }
        const prefixes = {
            hTokenNamePrefix: "HyperEVM Testnet",
            symbolPrefix: "HyperEvmTest",
            debtTokenPrefix: "HyperEVM Testnet",
        }
        let encodedProposal = await encodeListingProposal(proposal)

        //create proposal
        const listingConfigEngine = await (await ethers.getContractFactory("ListingConfigEngine")).deploy(
            encodedProposal, proposal.description, 
            prefixes.hTokenNamePrefix, prefixes.symbolPrefix, prefixes.debtTokenPrefix
        )
        const proposalDetails = await listingConfigEngine.getProposal()
        
        //verify the proposal data is correct
        expect(proposalDetails.proposalId).to.equal(proposal.proposalId)

        expect(proposalDetails.marketConfig.priceSource).to.equal(proposal.marketConfig.priceSource)
        expect(proposalDetails.marketConfig.poolAddressesProvider).to.equal(proposal.marketConfig.poolAddressesProvider)

        expect(proposalDetails.assetConfig.underlyingAsset).to.equal(proposal.assetConfig.underlyingAsset)
        expect(proposalDetails.assetConfig.aTokenImpl).to.equal(proposal.assetConfig.aTokenImpl)
        expect(proposalDetails.assetConfig.stableDebtTokenImpl).to.equal(proposal.assetConfig.stableDebtTokenImpl)
        expect(proposalDetails.assetConfig.variableDebtTokenImpl).to.equal(proposal.assetConfig.variableDebtTokenImpl)
        expect(proposalDetails.assetConfig.interestRateStrategyAddress).to.equal(proposal.assetConfig.interestRateStrategyAddress)
        expect(proposalDetails.assetConfig.treasury).to.equal(proposal.assetConfig.treasury)
        expect(proposalDetails.assetConfig.incentivesController).to.equal(proposal.assetConfig.incentivesController)

        expect(proposalDetails.assetConfig.reserveConfig.baseLTV).to.equal(proposal.assetConfig.reserveConfig.baseLTV)
        expect(proposalDetails.assetConfig.reserveConfig.liquidationThreshold).to.equal(proposal.assetConfig.reserveConfig.liquidationThreshold)
        expect(proposalDetails.assetConfig.reserveConfig.liquidationBonus).to.equal(proposal.assetConfig.reserveConfig.liquidationBonus)
        expect(proposalDetails.assetConfig.reserveConfig.reserveFactor).to.equal(proposal.assetConfig.reserveConfig.reserveFactor)
        expect(proposalDetails.assetConfig.reserveConfig.borrowCap).to.equal(proposal.assetConfig.reserveConfig.borrowCap)
        expect(proposalDetails.assetConfig.reserveConfig.supplyCap).to.equal(proposal.assetConfig.reserveConfig.supplyCap)
        expect(proposalDetails.assetConfig.reserveConfig.stableBorrowingEnabled).to.equal(proposal.assetConfig.reserveConfig.stableBorrowingEnabled)
        expect(proposalDetails.assetConfig.reserveConfig.borrowingEnabled).to.equal(proposal.assetConfig.reserveConfig.borrowingEnabled)
        expect(proposalDetails.assetConfig.reserveConfig.flashLoanEnabled).to.equal(proposal.assetConfig.reserveConfig.flashLoanEnabled)
        expect(proposalDetails.assetConfig.reserveConfig.seedAmount).to.equal(proposal.assetConfig.reserveConfig.seedAmount)
        expect(proposalDetails.assetConfig.reserveConfig.seedAmountsHolder).to.equal(proposal.assetConfig.reserveConfig.seedAmountsHolder)

        expect(await listingConfigEngine.getMetadata()).to.deep.equal([
            proposal.description, prefixes.hTokenNamePrefix, prefixes.symbolPrefix, prefixes.debtTokenPrefix
        ])

        //get config contracts instances
        const poolAddressesProvider = await ethers.getContractAt(
            "contracts/dependencies/interfaces/IPoolAddressesProvider.sol:IPoolAddressesProvider", 
            proposal.marketConfig.poolAddressesProvider, owner
        );
        const aclManager = await ethers.getContractAt(
            "contracts/dependencies/interfaces/IACLManager.sol:IACLManager", 
            (await poolAddressesProvider.getACLManager()), owner
        ); 
    
        //mint & approve configEgine to spend token we are adding (so new reserve can be seeded)
        await newToken.connect(owner).mint(proposal.assetConfig.reserveConfig.seedAmount)
        await newToken.connect(owner).approve(listingConfigEngine.target, proposal.assetConfig.reserveConfig.seedAmount)
    
        //impersonate acl admin
        const aclAdmin = await poolAddressesProvider.getACLAdmin();
        await ethers.provider.send("hardhat_impersonateAccount", [aclAdmin]);
        const aclAdminSigner = await ethers.getSigner(aclAdmin);
    
        //make configEngine riskAdmin & listingsAdmin
        await aclManager.connect(aclAdminSigner).addRiskAdmin(listingConfigEngine.target)
        await aclManager.connect(aclAdminSigner).addAssetListingAdmin(listingConfigEngine.target)

        //execute proposal to add the token
        await listingConfigEngine.connect(owner).executeProposal()

        //verify pool was correctly created
        const pool = await env.getContractInstanceById("poolProxy")
        let reserveData = await pool.getReserveData(proposal.assetConfig.underlyingAsset)
        expect(reserveData[7]).to.equal(1) //reserve ID: second asset added
        expect(reserveData[11]).to.equal(proposal.assetConfig.interestRateStrategyAddress)

        const hToken = await ethers.getContractAt("contracts/dependencies/interfaces/IERC20Detailed.sol:IERC20Detailed", reserveData[8], owner);
        expect(await hToken.totalSupply()).to.equal(proposal.assetConfig.reserveConfig.seedAmount)
        expect(await hToken.name()).to.equal(`HyperLend ${prefixes.hTokenNamePrefix} MOCK2`)
        expect(await hToken.symbol()).to.equal(`h${prefixes.symbolPrefix}MOCK2`)
        expect(await hToken.balanceOf(proposalDetails.assetConfig.reserveConfig.seedAmountsHolder)).to.equal(proposal.assetConfig.reserveConfig.seedAmount)
    });
});