/// <reference types="../types/truffle-contracts" />

const Example = artifacts.require("Example");

module.exports = async function (deployer, network) {
    await deployer.deploy(Example);
}
