# Stake & Bet contracts

* **ApiConsumer** : This contract call the associated external adapter to retrieve a tweet count
* **BetManager** : This contract is responsible for managing the betting system. It will be responsible for creating and managing the bets.
* **BetPool** : This contract is the stacking pool which is filled with bet fees.
* **BetStableSwap** : The purpose of this contract is to provide a simple way to swap between two tokens. It is not meant to be used as a liquidity pool, but rather as a way to swap between two tokens.
* **BetToken** : This is the token used for betting and staking in the Stake & Bet platform.
* **Operator** : This contract transfer the API Consumer request to our Chainlink Node, then transfer the Node request to the API Consumer. 


## Environment Variables

To run this project, you will need to add the following environment variables to your `.env` file

* `PRIVATE_KEY` : Private key of the deployer
* `JOB_ID` : Chainlink JobID

## Installation

```bash
  forge install
```
## Running Tests

To run tests, run the following command

```bash
  forge test --rpc-url https://eth-goerli.public.blastapi.io
```

## Deployment

* Deployer should have at least 10 $LINK
* `.env` needs to contains variables cited above

Run the following command

```bash
  forge script script/Deploy.s.sol --rpc-url https://eth-goerli.public.blastapi.io   --slow --broadcast
```
