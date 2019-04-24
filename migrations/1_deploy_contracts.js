/// <reference types="../test-ts/typings/truffle" />

const Example = artifacts.require("Example");

module.exports = async function (deployer, network) {
    await deployer.deploy(Example);
    await deployer.deploy(Example);
}