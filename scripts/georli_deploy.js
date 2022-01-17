const ethers = require('ethers');
const { getContractFactory, deployContract } = require('./common.js');

ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);
const { parseEther: toWei, formatBytes32String: toBytes32 } = ethers.utils;

// requires setting ETH_FROM_KEY and ETH_RPC_URL and a running instance of a network
(async function () {
    const deployer = new ethers.Wallet(process.env.ETH_FROM_KEY, new ethers.providers.JsonRpcProvider(process.env.ETH_RPC_URL));
    const me = await deployer.getAddress();

    // Deploy element finance value provider
    // PoolID: 0x4294005520c453eb8fa66f53042cfc79707855c400020000000000000000009a
    // Balancer Vault: 0x65748E8287Ce4B9E6D83EE853431958851550311
    // Underlier : 0x78dEca24CBa286C0f8d56370f5406B48cFCE2f86
    // Pt Bond : 0xDCf80C068B7fFDF7273d8ADAE4B076BF384F711A
    // Time to maturity: 1660165080
    // Unit Seconds: 284012568

    const elementValueProvider = await deployContract('ElementVP', 
        await getContractFactory('src/valueprovider/ElementFinance/ElementFinanceValueProvider.sol', 'ElementFinanceValueProvider', deployer),
        "0x4294005520c453eb8fa66f53042cfc79707855c400020000000000000000009a",
        "0x65748E8287Ce4B9E6D83EE853431958851550311",
        "0x78dEca24CBa286C0f8d56370f5406B48cFCE2f86",
        "0xDCf80C068B7fFDF7273d8ADAE4B076BF384F711A",
        "1660165080",
        "284012568"
    );

    const elementOracle = await deployContract('ElementOracle',
        await getContractFactory('src/oracle/Oracle.sol', 'Oracle', deployer),
        elementValueProvider.address,
        "600",
        "1200",
        "100000000000000000"
    );

    const elementAggregator = await deployContract('ElementAggregator',
        await getContractFactory('src/aggregator/AggregatorOracle.sol', 'AggregatorOracle', deployer)  
    );

    await elementAggregator.oracleAdd(elementOracle.address);

    // Collybus goerli deployment: 0xa63FA19ec499F7755581Ff30E138767A856B3312
    const relayer = await deployContract('DiscountRateRelayer',
        await getContractFactory('src/relayer/CollybusDiscountRate/CollybusDiscountRateRelayer.sol', 'CollybusDiscountRateRelayer', deployer),
        "0xa63FA19ec499F7755581Ff30E138767A856B3312"
    );

    var oracleCount = await elementAggregator.oracleCount();
    console.log("Oracle count "+ oracleCount);

    await elementAggregator.setMinimumRequiredValidValues("1",{
        gasPrice: 1000000000,
        gasLimit: 300000
    });

    console.log("Post setMinimumRequiredValidValues");

    var tokenID = "1";
    var minimumThresholdValue = "1000000000";
    await relayer.oracleAdd(elementAggregator.address,tokenID,minimumThresholdValue);

    console.log("END");
})();