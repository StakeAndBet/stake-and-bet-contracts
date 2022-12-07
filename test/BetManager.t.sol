pragma solidity ^0.8.16;
import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {BetToken} from "../src/BetToken.sol";
import {BetManager} from "../src/BetManager.sol";
import {ApiConsumer} from "../src/ApiConsumer.sol";

contract BetManagerTest is Test {
  BetToken betToken;
  ApiConsumer apiConsumer;
  BetManager betManager;

  address public adminAddress = address(0x1337);

  // TODO: CHANGE TO REAL CONTRACT
  address public stackingContractAddress = address(0x666);
  address public teamAddress = address(0x667);

  event VerifiedTwitterUserIdAdded(string twitterUserId);
  event VerifiedTwitterUserIdRemoved(string twitterUserId);
  event NewApiConsumer(address oldApiConsumer, address newApiConsumer);

  function setUp() public {
    vm.startPrank(adminAddress);
    betToken = new BetToken();
    apiConsumer = new ApiConsumer();
    betManager = new BetManager(
      address(betToken),
      address(apiConsumer),
      stackingContractAddress,
      teamAddress
    );
    vm.stopPrank();
  }

  function test_initialState() public {
    assertEq(address(betManager.betToken()), address(betToken));
    assertEq(address(betManager.apiConsumer()), address(apiConsumer));
    assertEq(betManager.stackingContract(), stackingContractAddress);
    assertEq(betManager.teamAddress(), teamAddress);
    assertTrue(
      betManager.hasRole(betManager.DEFAULT_ADMIN_ROLE(), adminAddress)
    );
    assertTrue(
      betManager.hasRole(
        betManager.BETTING_SESSION_MANAGER_ROLE(),
        adminAddress
      )
    );
    assertTrue(
      betManager.hasRole(
        betManager.BETTING_SESSION_SETTLER_ROLE(),
        address(apiConsumer)
      )
    );
  }

  function test_addVerifiedTwitterUserId() public {
    string memory twitterUserId = "elonmusk";

    // Unauthorized user
    vm.expectRevert(
      "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0xb632ceb29ddb0fd6911a1ecacc940fb8a2533fca9a43a6be01463b90910665db"
    );
    betManager.addVerifiedTwitterUserId(twitterUserId);

    // Authorized user
    vm.startPrank(adminAddress);
    vm.expectEmit(true, false, false, true);
    emit VerifiedTwitterUserIdAdded(twitterUserId);
    betManager.addVerifiedTwitterUserId(twitterUserId);
    assertTrue(betManager.isTwitterIdVerified(twitterUserId));

    // Ensure no duplicates events
    vm.expectRevert("BetManager: Twitter user ID is already verified");
    betManager.addVerifiedTwitterUserId(twitterUserId);
  }

  function test_removeVerifiedTwitterUserId() public {
    string memory twitterUserId = "elonmusk";
    vm.prank(adminAddress);
    betManager.addVerifiedTwitterUserId(twitterUserId);

    // Unauthorized user
    vm.expectRevert(
      "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0xb632ceb29ddb0fd6911a1ecacc940fb8a2533fca9a43a6be01463b90910665db"
    );
    betManager.removeVerifiedTwitterUserId(twitterUserId);

    // Authorized user
    vm.startPrank(adminAddress);
    vm.expectEmit(true, false, false, true);
    emit VerifiedTwitterUserIdRemoved(twitterUserId);
    betManager.removeVerifiedTwitterUserId(twitterUserId);
    assertFalse(betManager.isTwitterIdVerified(twitterUserId));

    // Ensure no duplicates events
    vm.expectRevert("BetManager: Twitter user ID is not already verified");
    betManager.removeVerifiedTwitterUserId(twitterUserId);
  }

  function test_setApiConsumer() public {
    address oldApiConsumer = address(betManager.apiConsumer());
    address newApiConsumer = address(0x123);

    // Unauthorized user
    vm.expectRevert(
      "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
    );
    betManager.setApiConsumer(newApiConsumer);

    // Authorized user
    vm.startPrank(adminAddress);
    vm.expectEmit(true, false, false, true);
    emit NewApiConsumer(oldApiConsumer, newApiConsumer);
    betManager.setApiConsumer(newApiConsumer);

    // No self assignment
    vm.expectRevert(
      "BetManager: ApiConsumer address must be different from current address"
    );
    betManager.setApiConsumer(newApiConsumer);

    // Non zero address
    vm.expectRevert("BetManager: ApiConsumer address must be non-zero");
    betManager.setApiConsumer(address(0));
    vm.stopPrank();

    assertEq(address(betManager.apiConsumer()), newApiConsumer);
    assertTrue(
      betManager.hasRole(
        betManager.BETTING_SESSION_SETTLER_ROLE(),
        newApiConsumer
      )
    );
    assertFalse(
      betManager.hasRole(
        betManager.BETTING_SESSION_SETTLER_ROLE(),
        oldApiConsumer
      )
    );
  }

  function test_createBettingSessionWithUnauthorizedUser(
    string memory twitterUserId,
    uint32 startTimestamp,
    uint32 endTimestamp
  ) public {
    vm.expectRevert(
      "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0xb632ceb29ddb0fd6911a1ecacc940fb8a2533fca9a43a6be01463b90910665db"
    );
    betManager.createBettingSession(
      startTimestamp,
      endTimestamp,
      twitterUserId
    );
  }

  function test_createBettingSession
}
