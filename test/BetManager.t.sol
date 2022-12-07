pragma solidity ^0.8.16;
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {BetToken} from "../src/BetToken.sol";
import {BetManager} from "../src/BetManager.sol";
import {ApiConsumer} from "../src/ApiConsumer.sol";

contract BetManagerTest is Test {
  BetToken betToken;
  ApiConsumer apiConsumer;
  BetManager betManager;

  address linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
  IERC20 linkToken;

  uint8 decimals = 18;

  address betTokenMinter = address(0x3333);

  address public adminAddress = address(0x1337);
  address public better1 = address(0x1);
  address public better2 = address(0x2);

  // TODO: CHANGE TO REAL CONTRACT
  address public stackingContractAddress = address(0x666);
  address public teamAddress = address(0x667);

  uint256[] public bets;

  event BettingSessionCreated(
    bytes32 indexed sessionId,
    uint32 startTimestamp,
    uint32 endTimestamp,
    string twitterUserId
  );
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

    betToken.grantRole(betToken.MINTER_ROLE(), betTokenMinter);
    betToken.addToWhitelist(address(betManager));
    apiConsumer.setBetManager(address(betManager));
    betManager.grantRole(
      betManager.BETTING_SESSION_SETTLER_ROLE(),
      address(apiConsumer)
    );
    vm.stopPrank();

    linkToken = IERC20(linkAddress);
    // Steal link
    vm.startPrank(0xE4dDb4233513498b5aa79B98bEA473b01b101a67);
    linkToken.transfer(
      address(apiConsumer),
      linkToken.balanceOf(0xE4dDb4233513498b5aa79B98bEA473b01b101a67)
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

  function test_createBettingSession() public {
    vm.warp(1670431112);
    string memory twitterUserId = "elonmusk";

    // Ensure only BETTING_SESSION_MANAGER_ROLE can call
    vm.expectRevert(
      "AccessControl: account 0x7fa9385be102ac3eac297483dd6233d62b3e1496 is missing role 0xb632ceb29ddb0fd6911a1ecacc940fb8a2533fca9a43a6be01463b90910665db"
    );
    betManager.createBettingSession(
      uint32(1670457600),
      uint32(1670543999),
      twitterUserId
    );

    vm.startPrank(adminAddress);
    betManager.addVerifiedTwitterUserId(twitterUserId);

    // Ensure startTimestamp is in the future
    vm.expectRevert("BetManager: Start timestamp must be in the future");
    betManager.createBettingSession(
      uint32(block.timestamp) - 1,
      uint32(block.timestamp),
      twitterUserId
    );

    // Ensure startTimestamp is at the beginning of a day
    vm.expectRevert(
      "BetManager: Start timestamp must be at the beginning of a day"
    );
    betManager.createBettingSession(
      uint32(1670454000),
      uint32(1670454000),
      twitterUserId
    );

    // Ensure endTimestamp is after startTimestamp
    vm.expectRevert("BetManager: End timestamp must be at the end of the day");
    betManager.createBettingSession(
      uint32(1670457600),
      uint32(1670457601),
      twitterUserId
    );

    // Ensure success creation
    bytes32 expectedSessionId = betManager.generateSessionId(
      twitterUserId,
      uint32(1670457600),
      uint32(1670543999)
    );
    vm.expectEmit(true, false, false, true);
    emit BettingSessionCreated(
      expectedSessionId,
      uint32(1670457600),
      uint32(1670543999),
      twitterUserId
    );
    bytes32 sessionId = betManager.createBettingSession(
      uint32(1670457600),
      uint32(1670543999),
      twitterUserId
    );
    assertEq(sessionId, expectedSessionId);

    // Ensure no duplicates
    vm.expectRevert("BetManager: Betting session already exists");
    betManager.createBettingSession(
      uint32(1670457600),
      uint32(1670543999),
      twitterUserId
    );

    // Ensure twitter user id is verified
    vm.expectRevert("BetManager: Twitter user id is not verified");
    betManager.createBettingSession(
      uint32(1670457600),
      uint32(1670543999),
      "NotVerified"
    );
    vm.stopPrank();
  }

  function test_placeBets() public {
    // 1st session
    vm.warp(1670431112);
    string memory twitterUserId = "elonmusk";
    vm.startPrank(adminAddress);
    betManager.addVerifiedTwitterUserId(twitterUserId);
    bytes32 sessionId = betManager.createBettingSession(
      uint32(1670457600),
      uint32(1670543999),
      twitterUserId
    );
    vm.stopPrank();

    vm.startPrank(better1);
    vm.expectRevert("BetManager: Betting session does not exist");
    uint256[] memory dummyBets = new uint256[](3);
    betManager.placeBets(bytes32(0), dummyBets);

    vm.warp(1670457600);
    vm.expectRevert("BetManager: Bets are closed");
    betManager.placeBets(sessionId, dummyBets);

    vm.warp(1670431112);
    uint256[] memory dummyEmptyBets = new uint256[](3);
    vm.expectRevert("BetManager: Not enough tokens to bet");
    betManager.placeBets(sessionId, dummyEmptyBets);
    vm.stopPrank();

    _mintTokens(better1, 100000 * 10**decimals);
    vm.startPrank(better1);
    vm.expectRevert("BetManager: No bets provided");
    betManager.placeBets(sessionId, bets);

    uint256[] memory insaneBetAmount = new uint256[](
      betManager.MAX_TOKENS_PER_SESSION() /
        betManager.TOKEN_AMOUNT_PER_BET() +
        1
    );
    betToken.approve(address(betManager), type(uint256).max);
    vm.expectRevert("BetManager: Max tokens per session exceeded");
    betManager.placeBets(sessionId, insaneBetAmount);

    // 1st real bet
    bets.push(20);
    bets.push(10);
    bets.push(10);
    uint256 beforeBetter1Balance = betToken.balanceOf(better1);
    uint256 beforeContractBalance = betToken.balanceOf(address(betManager));
    betToken.approve(address(betManager), type(uint256).max);
    betManager.placeBets(sessionId, bets);
    uint256 afterBetter1Balance = betToken.balanceOf(better1);
    uint256 afterContractBalance = betToken.balanceOf(address(betManager));

    (, uint256 units, uint256 totalTokenBet, , ) = betManager.users(better1);
    uint256 totalTokenBetCurrentSession = betManager
      .totalTokensBetPerSessionIdPerUser(sessionId, better1);

    assertEq(
      units,
      (betManager.UNITS_PER_TOKEN() * totalTokenBet) / 10**decimals
    );
    assertEq(totalTokenBetCurrentSession, totalTokenBet);
    assertTrue(
      beforeBetter1Balance - afterBetter1Balance ==
        betManager.TOKEN_AMOUNT_PER_BET() * bets.length
    );
    assertTrue(
      afterContractBalance - beforeContractBalance ==
        betManager.TOKEN_AMOUNT_PER_BET() * bets.length
    );

    // 2nd real bet
    bets.push(30);
    bets.push(20);
    bets.push(10);
    beforeBetter1Balance = betToken.balanceOf(better1);
    beforeContractBalance = betToken.balanceOf(address(betManager));
    betToken.approve(address(betManager), type(uint256).max);
    betManager.placeBets(sessionId, bets);
    afterBetter1Balance = betToken.balanceOf(better1);
    afterContractBalance = betToken.balanceOf(address(betManager));

    (, units, totalTokenBet, , ) = betManager.users(better1);
    totalTokenBetCurrentSession = betManager.totalTokensBetPerSessionIdPerUser(
      sessionId,
      better1
    );

    assertEq(
      units,
      (betManager.UNITS_PER_TOKEN() * totalTokenBet) / 10**decimals
    );
    assertEq(totalTokenBetCurrentSession, totalTokenBet);
    assertTrue(
      beforeBetter1Balance - afterBetter1Balance ==
        betManager.TOKEN_AMOUNT_PER_BET() * bets.length
    );
    assertTrue(
      afterContractBalance - beforeContractBalance ==
        betManager.TOKEN_AMOUNT_PER_BET() * bets.length
    );
    vm.stopPrank();

    // 2nd session
    twitterUserId = "elonmusk2";
    vm.startPrank(adminAddress);
    betManager.addVerifiedTwitterUserId(twitterUserId);
    sessionId = betManager.createBettingSession(
      uint32(1670457600),
      uint32(1670543999),
      twitterUserId
    );
    vm.stopPrank();

    // 1st real bet
    vm.startPrank(better1);
    uint256 totalTokenBetOldSession = totalTokenBetCurrentSession;
    delete bets;
    bets.push(20);
    bets.push(10);
    beforeBetter1Balance = betToken.balanceOf(better1);
    beforeContractBalance = betToken.balanceOf(address(betManager));
    betToken.approve(address(betManager), type(uint256).max);
    betManager.placeBets(sessionId, bets);
    afterBetter1Balance = betToken.balanceOf(better1);
    afterContractBalance = betToken.balanceOf(address(betManager));

    (, units, totalTokenBet, , ) = betManager.users(better1);
    totalTokenBetCurrentSession = betManager.totalTokensBetPerSessionIdPerUser(
      sessionId,
      better1
    );

    assertEq(
      units,
      (betManager.UNITS_PER_TOKEN() * totalTokenBet) / 10**decimals
    );
    assertEq(
      totalTokenBetCurrentSession + totalTokenBetOldSession,
      totalTokenBet
    );
    assertTrue(
      beforeBetter1Balance - afterBetter1Balance ==
        betManager.TOKEN_AMOUNT_PER_BET() * bets.length
    );
    assertTrue(
      afterContractBalance - beforeContractBalance ==
        betManager.TOKEN_AMOUNT_PER_BET() * bets.length
    );

    vm.stopPrank();
  }

  function test_endBettingSession() public {
    vm.warp(1670431112);
    string memory twitterUserId = "elonmusk";
    vm.startPrank(adminAddress);
    betManager.addVerifiedTwitterUserId(twitterUserId);
    bytes32 sessionId = betManager.createBettingSession(
      uint32(1670457600),
      uint32(1670543999),
      twitterUserId
    );
    vm.stopPrank();
    _mintTokens(better1, 100000 * 10**decimals);

    vm.startPrank(better1);
    bets.push(20);
    bets.push(10);
    bets.push(10);
    betToken.approve(address(betManager), type(uint256).max);
    betManager.placeBets(sessionId, bets);
    vm.stopPrank();

    vm.prank(better1);
    vm.expectRevert(
      "AccessControl: account 0x0000000000000000000000000000000000000001 is missing role 0xb632ceb29ddb0fd6911a1ecacc940fb8a2533fca9a43a6be01463b90910665db"
    );
    betManager.endBettingSession(bytes32(0));

    vm.startPrank(adminAddress);
    vm.expectRevert("BetManager: Betting session does not exist");
    betManager.endBettingSession(bytes32(0));

    vm.warp(1670543999);
    vm.expectRevert("BetManager: Betting session is not over yet");
    betManager.endBettingSession(sessionId);

    vm.warp(1670544000);
    bytes32 sessionRequestId = betManager.endBettingSession(sessionId);
    assertTrue(sessionRequestId != bytes32(0));

    vm.stopPrank();

    // Simulate Chainlink response
    address oracle = apiConsumer.chainlinkOracleAddr();
    vm.startPrank(oracle);
    apiConsumer.fulfill(sessionRequestId, 20);
    vm.stopPrank();
  }

  function _mintTokens(address account, uint256 amount) private {
    vm.prank(betTokenMinter);
    betToken.mint(account, amount);
  }
}
