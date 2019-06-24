import BN from "bn.js";
import { randomBytes } from "crypto";
import { ecrecover, ecsign, pubToAddress } from "ethereumjs-util";
import { keccak256 } from "web3-utils";

import {
    ShifterInstance, UniswapExchangeAdapterInstance, UniswapExchangeInstance,
    UniswapReserveAdapterInstance, zBTCInstance, UniswapFactoryInstance
} from "../types/truffle-contracts";
import { NULL, ETHEREUM_TOKEN_ADDRESS } from './helper/testUtils';

const Shifter = artifacts.require("Shifter");
const zBTC = artifacts.require("zBTC");
const UniswapExchange = artifacts.require("UniswapExchange");
const UniswapReserveAdapter = artifacts.require("UniswapReserveAdapter");
const UniswapExchangeAdapter = artifacts.require("UniswapExchangeAdapter");
const UniswapFactory = artifacts.require("UniswapFactory");

contract("UniswapAdapter", ([trader, reserveOwner, relayer, feeRecipient]) => {
    let mintAuthority, privKey;
    let uniswap, exchangeTemplate: UniswapExchangeInstance;
    let uniswapFactory: UniswapFactoryInstance;
    let uniswapReserveAdapter: UniswapReserveAdapterInstance;
    let uniswapExchangeAdapter: UniswapExchangeAdapterInstance;
    let btcShifter: ShifterInstance;
    let zbtc: zBTCInstance;

    before(async () => {
        zbtc = await zBTC.new();
        mintAuthority = web3.eth.accounts.create();
        privKey = Buffer.from(mintAuthority.privateKey.slice(2), "hex");
        uniswapFactory = await UniswapFactory.new();
        exchangeTemplate = await UniswapExchange.new();
        await uniswapFactory.initializeFactory(exchangeTemplate.address);
        await uniswapFactory.createExchange(zbtc.address);
        let zbtcExchangeAddress = await uniswapFactory.getExchange(zbtc.address);
        uniswap = await UniswapExchange.at(zbtcExchangeAddress);
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
        const amount = new BN(200000000000000);
        const minLiquidity = 0;
        const deadline = 100000000000;
        const refundAddress = "0x";
        const payload = web3.eth.abi.encodeParameters(['uint256', 'bytes', 'uint256'], [minLiquidity, refundAddress, deadline]);
        const pHash = keccak256(payload);

        const [nHash, sigString] = await buildMint(uniswapReserveAdapter.address, pHash, btcShifter, amount);
        await uniswapReserveAdapter.addLiquidity(amount.toString(), nHash, sigString, minLiquidity, refundAddress, deadline, { from: reserveOwner, value: amount });
        (await zbtc.totalSupply()).should.bignumber.equal(amount);
    });

    it("Can remove liquidity", async () => {
        const deadline = 100000000000;
        const amount = new BN(200000000000000);
        const uniAmount = await uniswap.balanceOf(reserveOwner);
        await uniswap.approve(uniswapReserveAdapter.address, uniAmount, {from: reserveOwner});
        const before = await web3.eth.getBalance(reserveOwner);
        const tx = await uniswapReserveAdapter.removeLiquidity(uniAmount, amount, amount, "0x11", deadline, { from: reserveOwner, gasPrice: 10000000000 });
        const after = await web3.eth.getBalance(reserveOwner);
        (await zbtc.totalSupply()).should.bignumber.equal(0);
        const transferred = after-before+tx.receipt.cumulativeGasUsed * 10000000000;
        (amount.sub(new BN(transferred)).cmp(new BN(10000))).should.be.lte(0);
    });

    it("Can add liquidity after removing liquidity", async () => {
        const amount = new BN(200000000000000);
        const minLiquidity = 0;
        const deadline = 100000000000;
        const refundAddress = "0x";
        const payload = web3.eth.abi.encodeParameters(['uint256', 'bytes', 'uint256'], [minLiquidity, refundAddress, deadline]);
        const pHash = keccak256(payload);

        const [nHash, sigString] = await buildMint(uniswapReserveAdapter.address, pHash, btcShifter, amount);
        await uniswapReserveAdapter.addLiquidity(amount.toString(), nHash, sigString, minLiquidity, refundAddress, deadline, { from: reserveOwner, value: amount });
        (await zbtc.totalSupply()).should.bignumber.equal(amount);
    });

    it("Can buy btc with eth", async () => {
        const amount = new BN(50000);
        const deadline = 100000000000;
        const before = new BN(await zbtc.totalSupply());
        const to = "0x11";
        const btcAmount = await uniswap.getEthToTokenInputPrice(amount.toString());
        await uniswapExchangeAdapter.buy(to, btcAmount, ETHEREUM_TOKEN_ADDRESS, amount, deadline, { from: trader, value: amount });
        const after = new BN(await zbtc.totalSupply());
        (before.sub(after)).should.bignumber.equal(btcAmount);
    })

    it("Can sell btc for eth without a relayer", async () => {
        const amount = new BN(50000);
        const relayFee = 0;
        const deadline = 100000000000;
        const refundAddress = "0x";

        const ethAmount = new BN(await uniswap.getTokenToEthInputPrice(amount.toString())).toNumber();
        const payload = web3.eth.abi.encodeParameters(['uint256', 'address', 'uint256', 'bytes', 'uint256'], [relayFee, trader, ethAmount, refundAddress, deadline]);
        const pHash = keccak256(payload);
        const [nHash, sigString] = await buildMint(uniswapExchangeAdapter.address, pHash, btcShifter, amount);

        const before = await web3.eth.getBalance(trader);
        const tx = await uniswapExchangeAdapter.sell(amount.toString(), nHash, sigString, relayFee, trader, ethAmount, refundAddress, deadline, { from: trader, gasPrice: 10000000000 });
        const after = await web3.eth.getBalance(trader);
        const received = after-before+tx.receipt.cumulativeGasUsed * 10000000000;
        (new BN(ethAmount).sub(new BN(received)).cmp(new BN(10000))).should.be.lte(0);
    })

    it("Can sell btc for eth with a relayer without a fee", async () => {
        const amount = new BN(50000);
        const relayFee = 0;
        const deadline = 100000000000;
        const refundAddress = "0x";

        const ethAmount = new BN(await uniswap.getTokenToEthInputPrice(amount.toString())).toNumber();
        const payload = web3.eth.abi.encodeParameters(['uint256', 'address', 'uint256', 'bytes', 'uint256'], [relayFee, trader, ethAmount, refundAddress, deadline]);
        const pHash = keccak256(payload);
        const [nHash, sigString] = await buildMint(uniswapExchangeAdapter.address, pHash, btcShifter, amount);

        const before = await web3.eth.getBalance(trader);
        await uniswapExchangeAdapter.sell(amount.toString(), nHash, sigString, relayFee, trader, ethAmount, refundAddress, deadline, { from: relayer });
        const after = await web3.eth.getBalance(trader);
        (after - before - ethAmount).should.lte(0);
    })

    it("Can sell btc for eth with a relayer with a fee", async () => {
        const amount = new BN(50000);
        const relayFee = 1000;
        const deadline = 100000000000;
        const refundAddress = "0x";

        const ethAmount = new BN(await uniswap.getTokenToEthInputPrice(amount.toString())).toNumber();
        const payload = web3.eth.abi.encodeParameters(['uint256', 'address', 'uint256', 'bytes', 'uint256'], [relayFee, trader, ethAmount, refundAddress, deadline]);
        const pHash = keccak256(payload);
        const [nHash, sigString] = await buildMint(uniswapExchangeAdapter.address, pHash, btcShifter, amount);

        const before = await web3.eth.getBalance(trader);
        await uniswapExchangeAdapter.sell(amount.toString(), nHash, sigString, relayFee, trader, ethAmount, refundAddress, deadline, { from: relayer, gasPrice: 10000000000 });
        const after = await web3.eth.getBalance(trader);
        (after - before - ethAmount + relayFee).should.lte(500);
    })

    it("Can remove liquidity after trading", async () => {
        const deadline = 100000000000;
        const amount = new BN(200000000000000);
        const withdrawAmount = new BN(100000000000000);
        const uniAmount = await uniswap.balanceOf(reserveOwner);
        await uniswap.approve(uniswapReserveAdapter.address, uniAmount, {from: reserveOwner});
        const before = await web3.eth.getBalance(reserveOwner);
        const tx = await uniswapReserveAdapter.removeLiquidity(uniAmount, withdrawAmount, withdrawAmount, "0x11", deadline, { from: reserveOwner, gasPrice: 10000000000 });
        const after = await web3.eth.getBalance(reserveOwner);
        (await zbtc.totalSupply()).should.bignumber.equal(0);
        const transferred = after-before+tx.receipt.cumulativeGasUsed * 10000000000;
    });
});
