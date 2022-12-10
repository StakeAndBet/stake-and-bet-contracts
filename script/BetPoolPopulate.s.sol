// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {BetToken} from "../src/BetToken.sol";
import {BetPool} from "../src/BetPool.sol";




// This script is designed to set the executer as rewardDistributor on the BetPool contract, then populate the BetPool with 1000 BetTokens, then execute the notifyRewardAmount function on the BetPool contract.
contract BetPoolPopulate is Script {
    using SafeERC20 for BetToken;
    BetToken betToken;
    BetPool betPool;
    
    uint256 tokensForStacking = 1000 * 10**18;

    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    address deployerAddress = vm.rememberKey(deployerPrivateKey);

function run() public {
    vm.startBroadcast(deployerPrivateKey);

    betToken = BetToken(vm.envAddress("BET_TOKEN_ADDRESS"));
    betPool = BetPool(vm.envAddress("BET_POOL_ADDRESS"));

    betPool.setRewardDistributor(address(deployerAddress), true);
    betToken.safeTransfer(address(betPool), tokensForStacking);
    betPool.notifyRewardAmount(tokensForStacking);


    vm.stopBroadcast();

}

}