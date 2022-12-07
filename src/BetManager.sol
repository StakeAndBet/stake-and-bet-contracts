// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// The purpose of this contract is to manage the betting system.
// It will be responsible for creating and managing the bets.

// Game process:
// - The administrator sets up multiple bets, each one focusing on a particular day.
// - The subject of each bet is the number of tweets posted by a certain person on a given day.
// - Users can place one or more fixed-amount bets on each bet until the day specified by the bet has begun.
// - At the end of each day, the bet result for that day is retrieved by the administrator and a definition of the winner(s) is made. The winner(s) are the people who found the correct number of tweets or, failing that, the closest ones.
// - Users who have won can claim their tokens by directly calling this contract.

// External calls:
// - BetToken
// - ConsumerContract

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/access/AccessControl.sol";

import {BetToken} from "./BetToken.sol";
import {ApiConsumer} from "./ApiConsumer.sol";

contract BetManager is AccessControl {
  using SafeERC20 for BetToken;

  BetToken public betToken;
  ApiConsumer public apiConsumer;

  // TODO: CHANGE TO REAL CONTRACT
  address public stackingContract;
  address public teamAddress;

  uint256 public constant TOKEN_AMOUNT_PER_BET = 1 ether; // 1 betToken
  uint256 public immutable UNITS_PER_TOKEN = 1;
  uint256 private constant SHARE_DIVISOR = 10000;
  uint256 public constant MAX_TOKENS_PER_SESSION = 1000 ether; // 1000 betToken

  uint256 public constant WINNER_SHARE = 8000; // 80%
  uint256 public constant STACKING_SHARE = 750; // 7.5%
  uint256 public constant BURN_SHARE = 750; // 7.5%
  uint256 public constant TEAM_SHARE = 500; // 5%

  mapping(bytes32 => bool) public verifiedTwitterUserIds;

  enum SessionState {
    STARTED,
    RESULT_REQUESTED,
    SETTLED
  }

  struct User {
    uint256 tokenToClaim;
    uint256 units;
    uint256 totalTokensBet;
    uint256 totalTokensWon;
    // uint256 totalTokensLost;
    uint256 totalBetWon;
    // uint256 totalBetLost;
    mapping(bytes32 => uint256) totalTokensBetPerSessionId;
  }

  struct BettingSession {
    uint32 startTimestamp;
    uint32 endTimestamp;
    string twitterUserId;
    uint256 betResult;
    uint256 totalTokensBet;
    SessionState state;
  }

  mapping(bytes32 => mapping(uint256 => address[])) usersPerBetPerSessionId;

  mapping(bytes32 => BettingSession) public bettingSessions;

  mapping(address => User) public users;

  bytes32 public constant BETTING_SESSION_MANAGER_ROLE =
    keccak256("BETTING_SESSION_MANAGER_ROLE");
  bytes32 public constant BETTING_SESSION_SETTLER_ROLE =
    keccak256("BETTING_SESSION_SETTLER_ROLE");

  event BetsPlaced(
    bytes32 indexed sessionId,
    address indexed user,
    uint256[] bet
  );
  event BettingSessionCreated(
    bytes32 indexed sessionId,
    uint32 startTimestamp,
    uint32 endTimestamp,
    string twitterUserId
  );

  event VerifiedTwitterUserIdAdded(string twitterUserId);
  event VerifiedTwitterUserIdRemoved(string twitterUserId);
  event NewApiConsumer(address oldApiConsumer, address newApiConsumer);

  constructor(
    address _betToken,
    address _apiConsumer,
    address _stackingContract,
    address _teamAddress
  ) {
    require(
      _betToken != address(0),
      "BetManager: BetToken address must be non-zero"
    );
    require(
      _apiConsumer != address(0),
      "BetManager: ApiConsumer address must be non-zero"
    );
    require(
      _stackingContract != address(0),
      "BetManager: StackingContract address must be non-zero"
    );
    require(
      _teamAddress != address(0),
      "BetManager: TeamAddress address must be non-zero"
    );
    betToken = BetToken(_betToken);
    apiConsumer = ApiConsumer(_apiConsumer);
    stackingContract = _stackingContract;
    teamAddress = _teamAddress;

    _grantRole(BETTING_SESSION_SETTLER_ROLE, _apiConsumer);
    _grantRole(BETTING_SESSION_MANAGER_ROLE, msg.sender);
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  function createBettingSession(
    uint32 startTimestamp,
    uint32 endTimestamp,
    string calldata twitterUserId
  ) external onlyRole(BETTING_SESSION_MANAGER_ROLE) returns (bytes32) {
    require(
      startTimestamp > block.timestamp,
      "BetManager: Start timestamp must be in the future"
    );
    require(
      startTimestamp % 1 days == 0,
      "BetManager: Start timestamp must be at the beginning of a day"
    );
    require(
      endTimestamp == startTimestamp + 1 days - 1 seconds,
      "BetManager: End timestamp must be at the end of the day"
    );
    require(
      isTwitterIdVerified(twitterUserId),
      "BetManager: Twitter user id is not verified"
    );
    bytes32 sessionId = generateSessionId(
      twitterUserId,
      startTimestamp,
      endTimestamp
    );
    require(
      bettingSessions[sessionId].startTimestamp != startTimestamp &&
        stringToTwitterId(bettingSessions[sessionId].twitterUserId) !=
        stringToTwitterId(twitterUserId),
      "BetManager: Betting session already exists"
    );
    bettingSessions[sessionId] = BettingSession({
      startTimestamp: startTimestamp,
      endTimestamp: endTimestamp,
      twitterUserId: twitterUserId,
      betResult: 0,
      totalTokensBet: 0,
      state: SessionState.STARTED
    });
    emit BettingSessionCreated(
      sessionId,
      startTimestamp,
      endTimestamp,
      twitterUserId
    );
    return sessionId;
  }

  function placeBets(bytes32 sessionId, uint256[] calldata bets) external {
    require(
      bettingSessions[sessionId].startTimestamp != 0,
      "BetManager: Betting session does not exist"
    );
    require(
      bettingSessions[sessionId].startTimestamp > block.timestamp,
      "BetManager: Bets are closed"
    );
    require(bets.length > 0, "BetManager: No bets provided");
    uint256 totalTokensBet = bets.length * TOKEN_AMOUNT_PER_BET;
    require(
      totalTokensBet <= betToken.balanceOf(msg.sender),
      "BetManager: Not enough tokens to bet"
    );
    for (uint256 i = 0; i < bets.length; i++) {
      recordOneUserBet(sessionId, bets[i], msg.sender, TOKEN_AMOUNT_PER_BET);
    }
    betToken.safeTransferFrom(msg.sender, address(this), totalTokensBet);
    emit BetsPlaced(sessionId, msg.sender, bets);
    bettingSessions[sessionId].totalTokensBet += totalTokensBet;
  }

  function endBettingSession(bytes32 sessionId)
    external
    onlyRole(BETTING_SESSION_MANAGER_ROLE)
    returns (bytes32)
  {
    BettingSession storage session = bettingSessions[sessionId];
    require(
      session.startTimestamp != 0,
      "BetManager: Betting session does not exist"
    );
    require(
      session.endTimestamp < block.timestamp,
      "BetManager: Betting session is not over yet"
    );
    require(
      session.state != SessionState.SETTLED,
      "BetManager: Betting session is already settled"
    );
    // if (session.state != SessionState.RESULT_REQUESTED) {
    //   if (apiConsumer.tweetCountPerSessionId(sessionId) != 0) {
    //     session.state = SessionState.SETTLED;
    //     return;
    //   }
    // }
    session.state = SessionState.RESULT_REQUESTED;
    bytes32 sessionRequestId = apiConsumer.requestTweetCount(
      sessionId,
      session.twitterUserId,
      session.startTimestamp,
      session.endTimestamp
    );
    // TODO: Check link token balance of api consumer
    require(sessionRequestId != 0, "BetManager: Requesting tweet count failed");
    return sessionRequestId;
  }

  function addVerifiedTwitterUserId(string calldata verifiedTwitterUserId)
    external
    onlyRole(BETTING_SESSION_MANAGER_ROLE)
  {
    bytes32 twitterUserIdKey = stringToTwitterId(verifiedTwitterUserId);
    require(
      !verifiedTwitterUserIds[twitterUserIdKey],
      "BetManager: Twitter user ID is already verified"
    );
    verifiedTwitterUserIds[twitterUserIdKey] = true;
    emit VerifiedTwitterUserIdAdded(verifiedTwitterUserId);
  }

  function removeVerifiedTwitterUserId(string calldata verifiedTwitterUserId)
    external
    onlyRole(BETTING_SESSION_MANAGER_ROLE)
  {
    bytes32 twitterUserIdKey = stringToTwitterId(verifiedTwitterUserId);
    require(
      verifiedTwitterUserIds[twitterUserIdKey],
      "BetManager: Twitter user ID is not already verified"
    );
    verifiedTwitterUserIds[twitterUserIdKey] = false;
    emit VerifiedTwitterUserIdRemoved(verifiedTwitterUserId);
  }

  function recordOneUserBet(
    bytes32 sessionId,
    uint256 bet,
    address user,
    uint256 tokenBetAmount
  ) internal {
    usersPerBetPerSessionId[sessionId][bet].push(user);
    users[user].units += ((TOKEN_AMOUNT_PER_BET * UNITS_PER_TOKEN) / 1 ether);
    users[user].totalTokensBet += tokenBetAmount;
    users[user].totalTokensBetPerSessionId[sessionId] += tokenBetAmount;
    require(
      users[user].totalTokensBetPerSessionId[sessionId] <=
        MAX_TOKENS_PER_SESSION,
      "BetManager: Max tokens per session exceeded"
    );
  }

  function setApiConsumer(address newApiConsumer)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(
      newApiConsumer != address(0),
      "BetManager: ApiConsumer address must be non-zero"
    );
    require(
      newApiConsumer != address(apiConsumer),
      "BetManager: ApiConsumer address must be different from current address"
    );

    address oldApiConsumer = address(apiConsumer);
    _revokeRole(BETTING_SESSION_SETTLER_ROLE, oldApiConsumer);
    apiConsumer = ApiConsumer(newApiConsumer);
    _grantRole(BETTING_SESSION_SETTLER_ROLE, address(apiConsumer));
    emit NewApiConsumer(oldApiConsumer, newApiConsumer);
  }

  function settleSession(bytes32 sessionId, uint256 betResult)
    external
    onlyRole(BETTING_SESSION_SETTLER_ROLE)
    returns (bool)
  {
    BettingSession memory session = bettingSessions[sessionId];
    require(
      session.state == SessionState.RESULT_REQUESTED,
      "BetManager: Betting session must be in state RESULT_REQUESTED"
    );
    session.state = SessionState.SETTLED;
    session.betResult = betResult;

    // Calculate shares
    (
      uint256 tokensForWinner,
      uint256 tokensForStacking,
      uint256 tokensForBurn,
      uint256 tokensForTeam
    ) = calculateShares(session.totalTokensBet);

    // Determine winners
    address[] memory usersWhoWon = usersPerBetPerSessionId[sessionId][
      betResult
    ];

    // Distribute winner shares to winners
    for (uint256 i = 0; i < usersWhoWon.length; i++) {
      address user = usersWhoWon[i];
      uint256 tokensWon = tokensForWinner / usersWhoWon.length;
      users[user].tokenToClaim += tokensWon;
      users[user].totalTokensWon += tokensWon;
      users[user].totalBetWon += 1;
    }

    // Distribute stacking shares to stacking contract
    betToken.safeTransfer(stackingContract, tokensForStacking);

    // Distribute team shares to team
    betToken.safeTransfer(teamAddress, tokensForTeam);

    // Burn burn shares
    betToken.burn(tokensForBurn);

    return true;
  }

  function calculateShares(uint256 totalTokensToShare)
    internal
    pure
    returns (
      uint256 tokensForWinner,
      uint256 tokensForStacking,
      uint256 tokensForBurn,
      uint256 tokensForTeam
    )
  {
    tokensForWinner = (totalTokensToShare * WINNER_SHARE) / SHARE_DIVISOR;
    tokensForStacking = (totalTokensToShare * STACKING_SHARE) / SHARE_DIVISOR;
    tokensForBurn = (totalTokensToShare * BURN_SHARE) / SHARE_DIVISOR;
    tokensForTeam = (totalTokensToShare * TEAM_SHARE) / SHARE_DIVISOR;
  }

  function setTeamAddress(address newTeamAddress)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(
      newTeamAddress != address(0),
      "BetManager: Team address must be non-zero"
    );
    teamAddress = newTeamAddress;
  }

  function claimTokens() external {
    require(
      users[msg.sender].tokenToClaim > 0,
      "BetManager: No tokens to claim"
    );
    uint256 tokensToClaim = users[msg.sender].tokenToClaim;
    users[msg.sender].tokenToClaim = 0;
    betToken.safeTransfer(msg.sender, tokensToClaim);
  }

  function generateSessionId(
    string calldata twitterUserId,
    uint256 startTimestamp,
    uint256 endTimestamp
  ) public pure returns (bytes32) {
    return
      keccak256(abi.encodePacked(twitterUserId, startTimestamp, endTimestamp));
  }

  function isTwitterIdVerified(string calldata twitterUserId)
    public
    view
    returns (bool)
  {
    return verifiedTwitterUserIds[stringToTwitterId(twitterUserId)];
  }

  function stringToTwitterId(string memory source)
    internal
    pure
    returns (bytes32 result)
  {
    result = keccak256(abi.encodePacked(source));
  }

  function totalTokensBetPerSessionIdPerUser(bytes32 sessionId, address user)
    external
    view
    returns (uint256)
  {
    return users[user].totalTokensBetPerSessionId[sessionId];
  }
}
