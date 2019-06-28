import BN from "bn.js";
import { randomBytes } from "crypto";
import { ecrecover, ecsign, pubToAddress } from "ethereumjs-util";
import { keccak256 } from "web3-utils";

import {
    ShifterInstance, UniswapExchangeAdapterInstance, UniswapExchangeInstance,
    UniswapReserveAdapterInstance, ERC20ShiftedInstance, UniswapFactoryInstance,
    UniswapAdapterFactoryInstance, ShifterRegistryInstance
} from "../types/truffle-contracts";
import { NULL, ETHEREUM_TOKEN_ADDRESS } from './helper/testUtils';

const Shifter = artifacts.require("Shifter");
const ShifterRegistry = artifacts.require("ShifterRegistry");
const zBTC = artifacts.require("zBTC");
const zZEC = artifacts.require("zZEC");
const UniswapExchange = artifacts.require("UniswapExchange");
const UniswapAdapterFactory = artifacts.require("UniswapAdapterFactory");
const UniswapReserveAdapter = artifacts.require("UniswapReserveAdapter");
const UniswapExchangeAdapter = artifacts.require("UniswapExchangeAdapter");
const UniswapFactory = artifacts.require("UniswapFactory");

contract("UniswapAdapter", ([trader, reserveOwner, relayer, feeRecipient]) => {
    let mintAuthority, privKey;
    let btcExchange, zecExchange, exchangeTemplate: UniswapExchangeInstance;
    let uniswapFactory: UniswapFactoryInstance;
    let uniswapAdapterFactory: UniswapAdapterFactoryInstance;
    let btcUniswapReserveAdapter, zecUniswapReserveAdapter: UniswapReserveAdapterInstance;
    let btcUniswapExchangeAdapter, zecUniswapExchangeAdapter: UniswapExchangeAdapterInstance;
    let btcShifter, zecShifter: ShifterInstance;
    let shifterRegistry: ShifterRegistryInstance;
    let zbtc, zzec: ERC20ShiftedInstance;

    before(async () => {
        // Deploy btc and zec shifted tokens.
        zbtc = await zBTC.new();
        zzec = await zZEC.new();

        // Create a test mint authority.
        mintAuthority = web3.eth.accounts.create();
        privKey = Buffer.from(mintAuthority.privateKey.slice(2), "hex");

        // Deploy btc and zec shifters.
        btcShifter = await Shifter.new(zbtc.address, feeRecipient, mintAuthority.address, 0);
        await zbtc.transferOwnership(btcShifter.address);
        await btcShifter.claimTokenOwnership();

        zecShifter = await Shifter.new(zzec.address, feeRecipient, mintAuthority.address, 0);
        await zzec.transferOwnership(zecShifter.address);
        await zecShifter.claimTokenOwnership();

        // Deploy shifter registry and register btc and zec shifters.
        shifterRegistry = await ShifterRegistry.new();
        await shifterRegistry.setShifter(zbtc.address, btcShifter.address);
        await shifterRegistry.setShifter(zzec.address, zecShifter.address);

        // Deploy uniswap factory
        exchangeTemplate = await UniswapExchange.new();
        uniswapFactory = await UniswapFactory.new();
        await uniswapFactory.initializeFactory(exchangeTemplate.address);
       
       // <-- The above setup already exists on kovan and mainnet -->
       uniswapAdapterFactory = await UniswapAdapterFactory.new(uniswapFactory.address, shifterRegistry.address);
       await uniswapAdapterFactory.createExchange(zbtc.address);
       await uniswapAdapterFactory.createExchange(zzec.address);

       const btcUniswapReserveAdapterAddress = await uniswapAdapterFactory.getReserveAdapter(zbtc.address);
       const btcUniswapExchangeAdapterAddress = await uniswapAdapterFactory.getExchangeAdapter(zbtc.address);
       const btcExchangeAddress = await uniswapFactory.getExchange(zbtc.address);

       const zecUniswapReserveAdapterAddress = await uniswapAdapterFactory.getReserveAdapter(zzec.address);
       const zecUniswapExchangeAdapterAddress = await uniswapAdapterFactory.getExchangeAdapter(zzec.address);
       const zecExchangeAddress = await uniswapFactory.getExchange(zzec.address);

       btcUniswapReserveAdapter = await UniswapReserveAdapter.at(btcUniswapReserveAdapterAddress);
       btcUniswapExchangeAdapter = await UniswapExchangeAdapter.at(btcUniswapExchangeAdapterAddress);
       btcExchange = await UniswapExchange.at(btcExchangeAddress);

       zecUniswapReserveAdapter = await UniswapReserveAdapter.at(zecUniswapReserveAdapterAddress);
       zecUniswapExchangeAdapter = await UniswapExchangeAdapter.at(zecUniswapExchangeAdapterAddress);
       zecExchange = await UniswapExchange.at(zecExchangeAddress);
    });

    const buildMint = async (user: string, pHash: string, shifter: ShifterInstance, value: BN) => {
        const nHash = `0x${randomBytes(32).toString("hex")}`;
        const hash = await shifter.hashForSignature(pHash, value.toNumber(), user, nHash);
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

        const [nHash, sigString] = await buildMint(btcUniswapReserveAdapter.address, pHash, btcShifter, amount);
        await btcUniswapReserveAdapter.addLiquidity(minLiquidity, refundAddress, deadline, amount.toString(), nHash, sigString,  { from: reserveOwner, value: amount });
        (await zbtc.totalSupply()).should.bignumber.equal(amount);
    });

    it("Can remove liquidity", async () => {
        const deadline = 100000000000;
        const amount = new BN(200000000000000);
        const uniAmount = await btcExchange.balanceOf(reserveOwner);
        await btcExchange.approve(btcUniswapReserveAdapter.address, uniAmount, {from: reserveOwner});
        const before = await web3.eth.getBalance(reserveOwner);
        const tx = await btcUniswapReserveAdapter.removeLiquidity(uniAmount, amount, amount, "0x11", deadline, { from: reserveOwner, gasPrice: 10000000000 });
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

        const [nHash, sigString] = await buildMint(btcUniswapReserveAdapter.address, pHash, btcShifter, amount);
        await btcUniswapReserveAdapter.addLiquidity(minLiquidity, refundAddress, deadline, amount.toString(), nHash, sigString, { from: reserveOwner, value: amount });
        (await zbtc.totalSupply()).should.bignumber.equal(amount);
    });

    it("Can buy btc with eth", async () => {
        const amount = new BN(50000);
        const deadline = 100000000000;
        const before = new BN(await zbtc.totalSupply());
        const to = "0x11";
        const btcAmount = await btcExchange.getEthToTokenInputPrice(amount.toString());
        await btcUniswapExchangeAdapter.buy(to, btcAmount, deadline, { from: trader, value: amount });
        const after = new BN(await zbtc.totalSupply());
        (before.sub(after)).should.bignumber.equal(btcAmount);
    })

    it("Can sell btc for eth without a relayer", async () => {
        const amount = new BN(50000);
        const relayFee = 0;
        const deadline = 100000000000;
        const refundAddress = "0x";

        const ethAmount = new BN(await btcExchange.getTokenToEthInputPrice(amount.toString())).toNumber();
        const payload = web3.eth.abi.encodeParameters(['uint256', 'address', 'uint256', 'bytes', 'uint256'], [relayFee, trader, ethAmount, refundAddress, deadline]);
        const pHash = keccak256(payload);
        const [nHash, sigString] = await buildMint(btcUniswapExchangeAdapter.address, pHash, btcShifter, amount);

        const before = await web3.eth.getBalance(trader);
        const tx = await btcUniswapExchangeAdapter.sell(relayFee, trader, ethAmount, refundAddress, deadline, amount.toString(), nHash, sigString, { from: trader, gasPrice: 10000000000 });
        const after = await web3.eth.getBalance(trader);
        const received = after-before+tx.receipt.cumulativeGasUsed * 10000000000;
        (new BN(ethAmount).sub(new BN(received)).cmp(new BN(10000))).should.be.lte(0);
    })

    it("Can sell btc for eth with a relayer without a fee", async () => {
        const amount = new BN(50000);
        const relayFee = 0;
        const deadline = 100000000000;
        const refundAddress = "0x";

        const ethAmount = new BN(await btcExchange.getTokenToEthInputPrice(amount.toString())).toNumber();
        const payload = web3.eth.abi.encodeParameters(['uint256', 'address', 'uint256', 'bytes', 'uint256'], [relayFee, trader, ethAmount, refundAddress, deadline]);
        const pHash = keccak256(payload);
        const [nHash, sigString] = await buildMint(btcUniswapExchangeAdapter.address, pHash, btcShifter, amount);

        const before = await web3.eth.getBalance(trader);
        await btcUniswapExchangeAdapter.sell( relayFee, trader, ethAmount, refundAddress, deadline, amount.toString(), nHash, sigString,{ from: relayer });
        const after = await web3.eth.getBalance(trader);
        (after - before - ethAmount).should.lte(0);
    })

    it("Can sell btc for eth with a relayer with a fee", async () => {
        const amount = new BN(50000);
        const relayFee = 1000;
        const deadline = 100000000000;
        const refundAddress = "0x";

        const ethAmount = new BN(await btcExchange.getTokenToEthInputPrice(amount.toString())).toNumber();
        const payload = web3.eth.abi.encodeParameters(['uint256', 'address', 'uint256', 'bytes', 'uint256'], [relayFee, trader, ethAmount, refundAddress, deadline]);
        const pHash = keccak256(payload);
        const [nHash, sigString] = await buildMint(btcUniswapExchangeAdapter.address, pHash, btcShifter, amount);

        const before = await web3.eth.getBalance(trader);
        await btcUniswapExchangeAdapter.sell( relayFee, trader, ethAmount, refundAddress, deadline, amount.toString(), nHash, sigString, { from: relayer, gasPrice: 10000000000 });
        const after = await web3.eth.getBalance(trader);
        (after - before - ethAmount + relayFee).should.lte(500);
    })

    it("Can remove liquidity after trading", async () => {
        const deadline = 100000000000;
        const amount = new BN(200000000000000);
        const withdrawAmount = new BN(100000000000000);
        const uniAmount = await btcExchange.balanceOf(reserveOwner);
        await btcExchange.approve(btcUniswapReserveAdapter.address, uniAmount, {from: reserveOwner});
        const before = await web3.eth.getBalance(reserveOwner);
        const tx = await btcUniswapReserveAdapter.removeLiquidity(uniAmount, withdrawAmount, withdrawAmount, "0x11", deadline, { from: reserveOwner, gasPrice: 10000000000 });
        const after = await web3.eth.getBalance(reserveOwner);
        (await zbtc.totalSupply()).should.bignumber.equal(0);
        const transferred = after-before+tx.receipt.cumulativeGasUsed * 10000000000;
    });
});
