import BN from "bn.js";
import { randomBytes } from "crypto";
import { ecrecover, ecsign, pubToAddress } from "ethereumjs-util";
import { keccak256 } from "web3-utils";

import {
    ShifterInstance, UniswapExchangeAdapterInstance, UniswapExchangeInstance,
    UniswapReserveAdapterInstance, zBTCInstance,
} from "../types/truffle-contracts";
import { NULL } from "./helper/testUtils";

const Shifter = artifacts.require("Shifter");
const zBTC = artifacts.require("zBTC");
const UniswapExchange = artifacts.require("UniswapExchange");
const UniswapReserveAdapter = artifacts.require("UniswapReserveAdapter");
const UniswapExchangeAdapter = artifacts.require("UniswapExchangeAdapter");

contract("UniswapAdapter", ([trader, reserveOwner, feeRecipient]) => {
    let mintAuthority, privKey;
    let uniswap: UniswapExchangeInstance;
    let uniswapReserveAdapter: UniswapReserveAdapterInstance;
    let uniswapExchangeAdapter: UniswapExchangeAdapterInstance;
    let btcShifter: ShifterInstance;
    let zbtc: zBTCInstance;

    before(async () => {
        zbtc = await zBTC.new();
        mintAuthority = web3.eth.accounts.create();
        privKey = Buffer.from(mintAuthority.privateKey.slice(2), "hex");
        uniswap = await UniswapExchange.new();
        await uniswap.setup(zbtc.address);
        btcShifter = await Shifter.new(NULL, zbtc.address, feeRecipient, mintAuthority.address, 0);
        await zbtc.transferOwnership(btcShifter.address);
        await btcShifter.claimTokenOwnership();

        uniswapReserveAdapter = await UniswapReserveAdapter.new(uniswap.address, btcShifter.address);
        uniswapExchangeAdapter = await UniswapExchangeAdapter.new(uniswap.address, btcShifter.address);
    });

    const buildMint = async (user: string, pHash: string, shifter: ShifterInstance, value: BN) => {
        const nHash = `0x${randomBytes(32).toString("hex")}`;
        const hash = await shifter.hashForSignature(user, value.toNumber(), nHash, pHash);
        const sig = ecsign(Buffer.from(hash.slice(2), "hex"), privKey);

        pubToAddress(ecrecover(Buffer.from(hash.slice(2), "hex"), sig.v, sig.r, sig.s)).toString("hex")
            .should.equal(mintAuthority.address.slice(2).toLowerCase());

        const sigString = `0x${sig.r.toString("hex")}${sig.s.toString("hex")}${(sig.v).toString(16)}`;

        (await shifter.verifySignature(hash, sigString))
            .should.be.true;

        return [nHash, sigString];
    }

    it("Can add liquidity", async () => {
        const amount = new BN(200000);
        const minLiquidity = 0;
        const deadline = 100000000000;
        const refundAddress = "0x";
        const payload = web3.eth.abi.encodeParameters(['uint256', 'uint256', 'bytes'], [minLiquidity, deadline, refundAddress]);
        const pHash = keccak256(payload);

        const [nHash, sigString] = await buildMint(uniswapReserveAdapter.address, pHash, btcShifter, amount);
        await uniswapReserveAdapter.addLiquidity(amount.toString(), nHash, sigString, minLiquidity, deadline, refundAddress, { from: reserveOwner, value: new BN(200000) });
        (await zbtc.totalSupply()).should.bignumber.equal(new BN(200000));
    });

    it("Can buy eth with btc", async () => {
        const amount = new BN(5000);
        const relayFee = 0;
        const minETH = 0;
        const deadline = 100000000000;
        const refundAddress = "0x";

        const payload = web3.eth.abi.encodeParameters(['uint256', 'bytes', 'uint256', 'uint256', 'bytes'], [relayFee, trader, minETH, deadline, refundAddress]);
        const pHash = keccak256(payload);
        const [nHash, sigString] = await buildMint(uniswapReserveAdapter.address, pHash, btcShifter, amount);

        const ethAmount = await uniswap.getTokenToEthInputPrice(amount.toString());
        const before = await web3.eth.getBalance(trader);
        await uniswapExchangeAdapter.buy(amount.toString(), nHash, sigString, relayFee, trader, minETH, deadline, refundAddress, { from: trader });
        const after = await web3.eth.getBalance(trader);
        // (after.minus(before)).should.equal(ethAmount);
    })

    it("Can sell eth for btc", async () => {
        const amount = new BN(5000);
        const minETH = 0;
        const deadline = 100000000000;
        const before = await zbtc.totalSupply();
        const btcAmount = await uniswap.getEthToTokenInputPrice(amount.toString());
        await uniswapExchangeAdapter.sell(minETH, trader, deadline, { from: trader, value: amount });
        const after = await zbtc.totalSupply();
        // (before.minus(after)).should.equal(btcAmount);
    })

    it("Can remove liquidity", async () => {
        const deadline = 100000000000;
        const uniAmount = await uniswap.balanceOf(reserveOwner);
        await uniswapReserveAdapter.removeLiquidity(uniAmount, 5000, 5000, deadline, "0x", { from: reserveOwner });
        (await zbtc.totalSupply()).should.equal(new BN(0));
    });
});
