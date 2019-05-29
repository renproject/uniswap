import "./helper/testUtils";

import { ExampleInstance } from "../types/truffle-contracts";

const Example = artifacts.require("Example");

contract("Example", (accounts) => {

    let example: ExampleInstance;

    before(async () => {
        example = await Example.new();;
    });

    it("Can call increment", async () => {
        await example.increment({ from: accounts[0] });
    });
});
