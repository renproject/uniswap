/// <reference types="../types/truffle-contracts" />

const UniswapAdapterFactory = artifacts.require("UniswapAdapterFactory");

const devnetShifterRegistry = "0xA28cC8B81906D2A42beF0bF782CECe3b75f91E6b"
const testnetShifterRegistry = "0x89aB0D4e64b1cb7F961228b70595a46BF0761546"
const kovanUniswapFactory = "0xD3E51Ef092B2845f10401a0159B2B96e8B6c3D30"

module.exports = async function (deployer, network) {
    if (network === "kovan") {
        const devnetUniswapAdapterFactory = await deployer.deploy(UniswapAdapterFactory, kovanUniswapFactory, devnetShifterRegistry);
        const testnetUniswapAdapterFactory = await deployer.deploy(UniswapAdapterFactory, kovanUniswapFactory, testnetShifterRegistry);

        console.log("Devnet UniswapAdapterFactory: ", devnetUniswapAdapterFactory.address);
        console.log("Testnet UniswapAdapterFactory: ", testnetUniswapAdapterFactory.address);
    }
}