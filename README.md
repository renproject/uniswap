# `solidity-typescript-boilerplate`

<!-- Replace ORG/REPO with organization and repository -->

[![Build Status](https://travis-ci.org/ORG/REPO.svg?branch=master)](https://travis-ci.org/ORG/REPO)
[![Coverage Status](https://coveralls.io/repos/github/ORG/REPO/badge.svg?branch=master)](https://coveralls.io/github/ORG/REPO?branch=master)

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
