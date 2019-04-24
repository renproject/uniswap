import "./helper/testUtils";

import { ExampleContract } from "./typings/bindings/example";

const Example = artifacts.require("Example");

contract("CompatibleERC20", (accounts) => {

    let example: ExampleContract;

    before(async () => {
        example = await Example.new();;
    });

    it("Can call setCompleted", async () => {
        await example.increment({ from: accounts[0] });
    });
});
