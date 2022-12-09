pragma solidity ^0.8.16;
import "forge-std/Test.sol";

import {ApiConsumer} from "../src/ApiConsumer.sol";
import {BetToken} from "../src/BetToken.sol";
import {BetManager} from "../src/BetManager.sol";
import {BetPool} from "../src/BetPool.sol";

contract BetPoolTest is Test {
  ApiConsumer apiConsumer;
  BetToken betToken;
  BetManager betManager;
  BetPool betPool;

  address adminAddress = address(0x1337);
  address teamAddress = address(0x666);

  address stacker1 = address(0x1);
  address stacker2 = address(0x2);

  function setUp() public {
    vm.startPrank(adminAddress);
    betToken = new BetToken();
    apiConsumer = new ApiConsumer();
    betPool = new BetPool(address(betToken), 1 days);
    betManager = new BetManager(
      address(betToken),
      address(apiConsumer),
      address(betPool),
      teamAddress
    );

    betToken.addToWhitelist(address(betPool));
    betToken.grantRole(betToken.MINTER_ROLE(), adminAddress);
    betToken.grantRole(betToken.MINTER_ROLE(), address(betPool));
    betPool.setRewardDistributor(address(betManager), true);

    betToken.mint(address(this), 1000 ether);
    betToken.mint(address(betManager), 1000 ether);
    betToken.mint(stacker1, 1000 ether);
    betToken.mint(stacker2, 1000 ether);
    vm.stopPrank();

    // Initial stacking
    // betToken.approve(address(betPool), type(uint256).max);
    // betPool.stake(1 ether);

    // distribute rewards
    vm.startPrank(address(betManager));
    betToken.transfer(address(betPool), 100 ether);
    betPool.notifyRewardAmount(100 ether);
    vm.stopPrank();

    // betToken.grantRole(betToken.MINTER_ROLE(), betTokenMinter);
    // betToken.addToWhitelist(address(betManager));
    // apiConsumer.setBetManager(address(betManager));
    // betManager.grantRole(
    //   betManager.BETTING_SESSION_SETTLER_ROLE(),
    //   address(apiConsumer)
    // );
    // linkToken = IERC20(linkAddress);
    // // Steal link
    // vm.startPrank(0xE4dDb4233513498b5aa79B98bEA473b01b101a67);
    // linkToken.transfer(
    //   address(apiConsumer),
    //   linkToken.balanceOf(0xE4dDb4233513498b5aa79B98bEA473b01b101a67)
    // );
    vm.stopPrank();
  }

  function test_stake() public {
    vm.startPrank(stacker1);
    betToken.approve(address(betPool), type(uint256).max);
    betPool.stake(1 ether);
    // vm.stopPrank();
    // vm.startPrank(stacker2);
    // betToken.approve(address(betPool), type(uint256).max);
    // betPool.stake(1 ether);

    vm.warp(block.timestamp + 1 hours);

    betPool.getReward();
    vm.stopPrank();

    // vm.warp(block.timestamp + 2 days);

    // vm.startPrank(address(betManager));
    // betToken.transfer(address(betPool), 100 ether);
    // betPool.notifyRewardAmount(100 ether);
    // vm.stopPrank();

    // vm.startPrank(stacker1);
    // vm.warp(block.timestamp + 1 days);
    // betPool.getReward();
    // vm.stopPrank();
    // vm.startPrank(stacker2);
    // vm.warp(block.timestamp + 10 days);
    // betPool.getReward();
    // vm.stopPrank();
  }

  function test_stake2() public {
    vm.startPrank(stacker1);
    betToken.approve(address(betPool), type(uint256).max);
    betPool.stake(1 ether);
    vm.stopPrank();
    vm.startPrank(stacker2);
    betToken.approve(address(betPool), type(uint256).max);
    betPool.stake(1 ether);
    vm.stopPrank();

    vm.warp(block.timestamp + 1 days);

    vm.startPrank(stacker1);
    betPool.exit();
    vm.stopPrank();

    vm.startPrank(stacker2);
    betPool.exit();
    vm.stopPrank();
  }
}
