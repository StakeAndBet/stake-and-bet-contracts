// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import {ApiConsumer} from "../src/ApiConsumer.sol";
import {BetToken} from "../src/BetToken.sol";
import {BetStableSwap} from "../src/BetStableSwap.sol";
import {BetManager} from "../src/BetManager.sol";
import {BetPool} from "../src/BetPool.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

// This script is designed to deploy all contracts and configure them on the Goerli testnet.
// daiAddress is the address of the DAI token on Goerli.
// operator is the address of the Chainlink operator on Goerli.
contract BetDeployGoerliIntegrationTest is Script {
  ApiConsumer apiConsumer;
  BetToken betToken;
  BetManager betManager;
  BetPool betPool;
  BetStableSwap betStableSwap;

  IERC20 linkToken;

  address daiAddress = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;
  address operatorAddress = 0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8;
  address linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;

  uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
  address deployerAddress = vm.rememberKey(deployerPrivateKey);
  string jobId = vm.envString("JOB_ID");

  function run() public {
    vm.startBroadcast(deployerPrivateKey);

    linkToken = IERC20(linkAddress);

    // Deploy contracts
    betToken = new BetToken();
    betStableSwap = new BetStableSwap(address(betToken), daiAddress);
    apiConsumer = new ApiConsumer();
    betPool = new BetPool(address(betToken), 1 days);
    betManager = new BetManager(
      address(betToken),
      address(apiConsumer),
      address(betPool),
      deployerAddress
    );

    // Configure betToken
    betToken.grantRole(betToken.MINTER_ROLE(), address(betStableSwap));
    betToken.revokeRole(betToken.MINTER_ROLE(), deployerAddress);
    betToken.addToWhitelist(address(betManager));
    betToken.addToWhitelist(address(betPool));

    // Configure betManager
    betManager.grantRole(
      betManager.BETTING_SESSION_SETTLER_ROLE(),
      address(apiConsumer)
    );

    // Configure betPool
    betPool.setRewardDistributor(address(betManager), true);

    // Configure apiConsumer
    apiConsumer.setBetManager(address(betManager));
    apiConsumer.setJobId(jobId);

    linkToken.transfer(address(apiConsumer), 10 ether); // 10 LINK

    betManager.addVerifiedTwitterUserId("elonmusk");

    // Create Betting Session of 1 days
    uint256 currentTimestamp = block.timestamp;
    uint256 startTimestamp = currentTimestamp -
      (currentTimestamp % 1 days) +
      1 days;
    for (uint256 i = 0; i < 10; i++) {
      betManager.createBettingSession(
        uint32(startTimestamp + (i * 1 days)),
        uint32(startTimestamp + (i * 1 days) + 1 days - 1 seconds),
        "elonmusk"
      );
    }
    vm.stopBroadcast();

    console.log("Deployer address: ", deployerAddress);
    console.log("BET_TOKEN#ADDR=", address(betToken));
    console.log("STABLE_TOKEN#ADDR=", daiAddress);
    console.log("BET_STABLE_SWAP#ADDR=", address(betStableSwap));
    console.log("BET_MANAGER#ADDR=", address(betManager));
    console.log("BET_POOL#ADDR=", address(betPool));
  }
}
