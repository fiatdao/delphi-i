const fs = require('fs');
const ethers = require('ethers');
const Artifacts = require('../out/dapp.sol.json');

ethers.utils.Logger.setLogLevel(ethers.utils.Logger.levels.ERROR);

function getContractFactory(path, name, deployer) {
  console.log(path + " " + name );
  const artifact = Artifacts.contracts[path][name];
  
  return new ethers.ContractFactory(artifact.abi, artifact.evm.bytecode, deployer);
}

function getContractAt(address, path, name, deployer)
{
  console.log(path + " " + name );
  const artifact = Artifacts.contracts[path][name];
  return new ethers.Contract(address, artifact.abi, deployer);
}

async function deployContract(name, factory, ...args) {
  const contract = await factory.deploy(...args);
  console.log(`${name}: ${contract.address}`);
  console.log(`  address: ${contract.address}`);
  console.log(`  txHash:  ${contract.deployTransaction.hash}`);
  const file = `${(await factory.signer.provider.getNetwork()).chainId}.json`;
  const addr = (fs.existsSync(file)) ? JSON.parse(fs.readFileSync(file)) : {};
  fs.writeFileSync(file, JSON.stringify({ ...addr, [name]: contract.address }, null, 2));
  return contract;
}

module.exports = { getContractFactory, deployContract, getContractAt };