// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "src/BetToken.sol";
import "src/BetStableSwap.sol";

contract BetDeploy is Script {
  address daiAddress = 0x11fE4B6AE13d2a6055C8D9cF65c55bac32B5d844;

  function setUp() public {}

  function run() public {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    vm.startBroadcast(deployerPrivateKey);
    BetToken betToken = new BetToken();
    BetStableSwap betStableSwap = new BetStableSwap(
      address(betToken),
      daiAddress
    );
    vm.stopBroadcast();

    console.log("BET_TOKEN#ADDR=", address(betToken));
    console.log("DAI#ADDR=", daiAddress);
    console.log("BET_STABLE_SWAP#ADDR=", address(betStableSwap));
  }
}
