# Rhodium45 Smart Portfolio

Rhodium45 Smart Portfolio is a BSC-focused cross-asset portfolio application combining RH45 with eligible tokenized stocks.

## Project Goal

The project explores how tokenized equities can be combined with a crypto-native RH45 allocation in a simple portfolio experience.

The application is being developed for the BNB HACK: Tokenized Stocks Edition.

## Planned MVP

The MVP will provide:

- Tokenized-stock discovery
- Tokenized-stock market/reference information
- RH45 portfolio allocation
- Target portfolio allocation
- Rebalancing calculations
- Wallet connection
- Transaction preview and simulation
- BSC-focused transaction flow

## RH45

Rhodium45 (RH) is the crypto asset used as the portfolio's crypto-side component.

The project does not represent the full RH45 token launch. Existing RH45 launch contracts and tokenomics remain separate from this hackathon MVP.

## Tokenized Stocks

The final implementation will use an eligible tokenized-stock integration supported by the hackathon requirements.

The specific tokenized stock and contract/address information will be documented after the integration is implemented and verified.

## Planned Architecture

User
↓
Rhodium45 Smart Portfolio
↓
Binance Web3 APIs
↓
Tokenized Stock Data
↓
RH45 / Crypto Portfolio
↓
BSC

## Planned API Usage

The MVP is expected to evaluate the following Binance Web3 API components:

- RWA Data API
- Market API
- Wallet API
- Transaction API

Additional APIs will only be included if they are actually implemented and tested.

## Development Approach

The project will first use API testing and transaction simulation before any live transaction flow.

No private keys, seed phrases, or wallet passwords are requested by the application.

## Status

🚧 In development

Features will be marked complete only after implementation and testing.

## Repository

GitHub:
https://github.com/katamvishnu7/rhodium45-smart-portfolio
