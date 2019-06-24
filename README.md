# `uniswap-adapter`

[![Build Status](https://travis-ci.org/renproject/uniswap.svg?branch=master)](https://travis-ci.org/renproject/uniswap)
[![Coverage Status](https://coveralls.io/repos/github/renproject/uniswap/badge.svg?branch=master)](https://coveralls.io/github/renproject/uniswap?branch=master)

This repository contains renshift adapters for the uniswap contracts. These adapters would allow users to 
interact with uniswap contracts that use ShiftedERC20 tokens.

## Tests

Install the dependencies.

```
yarn install
```

Run the `ganache-cli` or an alternate Ethereum test RPC server on port 8545. The `-d` flag will use a deterministic mnemonic for reproducibility.

```sh
yarn exec ganache-cli -d
```

Run the Truffle test suite.

```sh
yarn test
```

## Coverage

Install the dependencies.

```
yarn install
```

Run the Truffle test suite with coverage.

```sh
yarn coverage
```

## Deploying

Add a `.env`, filling in the mnemonic and Kovan ethereum node (e.g. Infura):

```sh
MNEMONIC="..."
KOVAN_ETHEREUM_NODE="..."
ETHERSCAN_KEY="..."
```

Deploy to Kovan:

```sh
NETWORK=kovan yarn run deploy
```

## Verifying Contract Code

```sh
NETWORK=kovan yarn run verify YourContractName
```
