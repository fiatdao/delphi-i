const ethers = require('ethers');
const { getContractFactory, deployContract } = require('./common.js');

ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);
const { parseEther: toWei, formatBytes32String: toBytes32 } = ethers.utils;

// requires setting ETH_FROM_KEY and ETH_RPC_URL and a running instance of a network
(async function () {
    const deployer = new ethers.Wallet(process.env.ETH_FROM_KEY, new ethers.providers.JsonRpcProvider(process.env.ETH_RPC_URL));
    const me = await deployer.getAddress();

    console.log("START");

    /*const elementValueProvider = await deployContract('GoerliDeploy', 
        await getContractFactory('src/deploy/GoerliDeploy.sol', 'GoerliDeploy', deployer)
    );*/

    const elementValueProvider = await deployContract('Factory', 
        await getContractFactory('src/factory/Factory.sol', 'Factory', deployer)
    );

    console.log("END");
})();