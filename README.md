[![CI and Tests](https://github.com/arch-protocol/chambers-peripherals/actions/workflows/CI.yml/badge.svg)](https://github.com/arch-protocol/chambers-peripherals/actions/workflows/CI.yml)

# Chambers Peripherals 

This repository contains peripheral contracts for an enhanced interaction with `Arch Chambers`.

#### Full documentation [here](https://docs.arch.finance/chambers/periphery/)

## About Arch

Arch is a decentralized finance (DeFi) asset manager that enables passive investment in the decentralized (Web3) economy.

We curate a comprehensive family of market indices and tokenized products to help investors build and manage their Web3 portfolios. 

## Peripherals contracts overview

Peripheral contracts main purpose is to enhance the interaction with Chambers core contracts. This type of contracts aren't part of Chambers Core contracts since they're not necessary for a fully functional chamber. Only External Wizard functions are called from peripheral contracts.

### Trade Issuer

The main function of this contract is to facilitate the purchase/sale of all the assets necessary for the issuance or redemption of tokens.

Using this contract, a user can mint or redeem Chamber Tokens with any erc20 asset or the native token of the network as input/output.


## Licensing

The primary license for Chambers Peripherals Contracts is Apache 2.0.


