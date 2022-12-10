// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/access/AccessControl.sol";

import {BetToken} from "./BetToken.sol";
import {BetPool} from "./BetPool.sol";
import {ApiConsumer} from "./ApiConsumer.sol";

/**
 * @author  stakeandbet@proton.me
 * @title   BetManager
 * @dev     This contract is responsible for managing the betting system. It will be responsible for creating and managing the bets.
 *         The game process is as follows:
 *         - The administrator sets up multiple bets, each one focusing on a particular day.
 *         - The subject of each bet is the number of tweets posted by a certain person on a given day.
 *         - Users can place one or more fixed-amount bets on each bet until the day specified by the bet has begun.
 *         - At the end of each day, the bet result for that day is retrieved by the administrator and a definition of the winner(s) is made. The winner(s) are the people who found the correct number of tweets or, failing that, the closest ones.
 *         - Users who have won can claim their tokens by directly calling this contract.
 */

contract BetManager is AccessControl {
  /// -----------------------------------------------------------------------
  /// Library usage
  /// -----------------------------------------------------------------------
  using SafeERC20 for BetToken;

  /// -----------------------------------------------------------------------
  /// Type declarations
  /// -----------------------------------------------------------------------

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

  /// -----------------------------------------------------------------------
  /// Constants
  /// -----------------------------------------------------------------------

  bytes32 public constant BETTING_SESSION_MANAGER_ROLE =
    keccak256("BETTING_SESSION_MANAGER_ROLE");
  bytes32 public constant BETTING_SESSION_SETTLER_ROLE =
    keccak256("BETTING_SESSION_SETTLER_ROLE");

  uint256 public constant TOKEN_AMOUNT_PER_BET = 1 ether; // 1 betToken
  uint256 public constant UNITS_PER_TOKEN = 1;
  uint256 private constant SHARE_DIVISOR = 10000;
  uint256 public constant MAX_TOKENS_PER_SESSION = 1000 ether; // 1000 betToken

  uint256 public constant WINNER_SHARE = 8000; // 80%
  uint256 public constant STACKING_SHARE = 750; // 7.5%
  uint256 public constant BURN_SHARE = 750; // 7.5%
  uint256 public constant TEAM_SHARE = 500; // 5%

  /// -----------------------------------------------------------------------
  /// Storage variables
  /// -----------------------------------------------------------------------

  BetToken public betToken;
  BetPool public betPool;
  ApiConsumer public apiConsumer;

  address public teamAddress;

  mapping(address => User) public users;
  mapping(bytes32 => mapping(uint256 => address[])) usersPerBetPerSessionId;
  mapping(bytes32 => BettingSession) public bettingSessions;
  mapping(bytes32 => bool) public verifiedTwitterUserIds;

  bytes32[] public bettingSessionIds;

  /// -----------------------------------------------------------------------
  /// Events
  /// -----------------------------------------------------------------------

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
  event BettingSessionEnded(bytes32 indexed sessionId);
  event BettingSessionSettled(bytes32 indexed sessionId, uint256 betResult);
  event TokenClaimed(address indexed user, uint256 tokenAmount);
  event VerifiedTwitterUserIdAdded(string twitterUserId);
  event VerifiedTwitterUserIdRemoved(string twitterUserId);
  event NewApiConsumer(address oldApiConsumer, address newApiConsumer);
  event NewTeamAddress(address oldTeamAddress, address newTeamAddress);

  constructor(
    address _betToken,
    address _apiConsumer,
    address _betPool,
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
      _betPool != address(0),
      "BetManager: StackingContract address must be non-zero"
    );
    require(
      _teamAddress != address(0),
      "BetManager: TeamAddress address must be non-zero"
    );
    betToken = BetToken(_betToken);
    apiConsumer = ApiConsumer(_apiConsumer);
    betPool = BetPool(_betPool);
    teamAddress = _teamAddress;

    // betToken.approve(address(betPool), type(uint256).max);

    _grantRole(BETTING_SESSION_SETTLER_ROLE, _apiConsumer);
    _grantRole(BETTING_SESSION_MANAGER_ROLE, msg.sender);
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /**
   * @notice Creates a new betting session
   * @dev Instanciate a new betting session and add it to the bettingSessions mapping with the sessionId as key
   * @param startTimestamp The timestamp of the start of the session
   * @param endTimestamp The timestamp of the end of the session
   * @param twitterUserId The Twitter user id of the user who created the session
   * @return The sessionId of the newly created session
   */
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
    bettingSessionIds.push(sessionId);
    emit BettingSessionCreated(
      sessionId,
      startTimestamp,
      endTimestamp,
      twitterUserId
    );
    return sessionId;
  }

  /**
   * @notice End a betting session
   * @dev This function is used to end a betting session when the end timestamp has passed. This will trigger a request for the tweet count associated with the betting session.
   * @param sessionId The ID of the betting session to end
   * @return sessionRequestId The ID of the Chainlink API request for the tweet count associated with this session
   */
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
    session.state = SessionState.RESULT_REQUESTED;
    bytes32 sessionRequestId = apiConsumer.requestTweetCount(
      sessionId,
      session.twitterUserId,
      session.startTimestamp,
      session.endTimestamp
    );
    // TODO: Check link token balance of api consumer
    require(sessionRequestId != 0, "BetManager: Requesting tweet count failed");
    emit BettingSessionEnded(sessionId);
    return sessionRequestId;
  }

  /**
   * @notice Settles a betting session and distributes shares to winners
   * @param sessionId bytes32 ID of the betting session to settle
   * @param betResult uint256 The result of the betting session
   * @return bool true if the session is successfully settled
   */
  // TODO: Gas optimization
  // TODO: Add approve to deposit tokens to stacking pool
  function settleBettingSession(bytes32 sessionId, uint256 betResult)
    external
    onlyRole(BETTING_SESSION_SETTLER_ROLE)
    returns (bool)
  {
    BettingSession storage session = bettingSessions[sessionId];
    require(
      session.state == SessionState.RESULT_REQUESTED,
      "BetManager: Betting session must be in state RESULT_REQUESTED"
    );
    session.state = SessionState.SETTLED;
    session.betResult = betResult;

    // Determine winners
    address[] memory usersWhoWon = usersPerBetPerSessionId[sessionId][
      betResult
    ];

    // Calculate shares
    (
      uint256 tokensForWinner,
      uint256 tokensForStacking,
      uint256 tokensForBurn,
      uint256 tokensForTeam
    ) = calculateShares(session.totalTokensBet);

    if (usersWhoWon.length == 0) {
      // No winners, distribute winner shares to stacking contract
      // Distribute stacking shares to stacking contract
      tokensForStacking += tokensForWinner;
    } else if (
      usersWhoWon.length * TOKEN_AMOUNT_PER_BET < tokensForWinner / 1e18
    ) {
      tokensForWinner = session.totalTokensBet;
      (tokensForStacking, tokensForBurn, tokensForTeam) = (0, 0, 0);
    }

    if (tokensForWinner > 0 && usersWhoWon.length > 0) {
      // Distribute winner shares to winners
      distributeWinnerShares(tokensForWinner, usersWhoWon);
    }

    if (tokensForStacking > 0) {
      // Distribute stacking shares to stacking contract
      betToken.safeTransfer(address(betPool), tokensForStacking);
      betPool.notifyRewardAmount(tokensForStacking);
    }

    if (tokensForTeam > 0) {
      // Distribute team shares to team address
      betToken.safeTransfer(teamAddress, tokensForTeam);
    }

    if (tokensForBurn > 0) {
      // Burn burn shares
      betToken.burn(tokensForBurn);
    }

    emit BettingSessionSettled(sessionId, betResult);
    return true;
  }

  /**
   * @notice Place bets for a particular session
   * @param sessionId ID of the session to place bets
   * @param bets Array of bets placed by the user
   * @dev This function is used to place bets for a particular session. The user must have enough tokens to place the bets.
   */
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
    bettingSessions[sessionId].totalTokensBet += totalTokensBet;
    emit BetsPlaced(sessionId, msg.sender, bets);
    betToken.safeTransferFrom(msg.sender, address(this), totalTokensBet);
  }

  /**
   * @notice Add a verified Twitter user ID to the list of verified Twitter user IDs
   * @dev    Only the betting session manager can call this function and the Twitter user ID must not already be verified.
   * @param   verifiedTwitterUserId  The verified Twitter user ID to add
   */
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

  /**
   * @notice Remove a verified Twitter user ID from the list of verified Twitter user IDs
   * @dev    Only the betting session manager can call this function and the Twitter user ID must be already be verified.
   * @param   verifiedTwitterUserId  The verified Twitter user ID to remove
   */
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

  /**
   * @notice  Sets the address of the ApiConsumer contract
   * @dev     Only the admin can call this function and the new address must be non-zero and different from the current address.
   * @param   newApiConsumer adress of the new ApiConsumer contract
   */
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

  /**
   * @notice  Sets the team address.
   * @dev     Only the admin can call this function and the new address must be non-zero and different from the current address.
   * @param   newTeamAddress  new team address
   */
  function setTeamAddress(address newTeamAddress)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(
      newTeamAddress != address(0),
      "BetManager: Team address must be non-zero"
    );
    address oldTeamAddress = teamAddress;
    require(
      newTeamAddress != oldTeamAddress,
      "BetManager: Team address must be different from current address"
    );
    teamAddress = newTeamAddress;
    emit NewTeamAddress(oldTeamAddress, newTeamAddress);
  }

  /**
   * @notice  Claims tokens for a user.
   */
  function claimTokens() external {
    require(
      users[msg.sender].tokenToClaim > 0,
      "BetManager: No tokens to claim"
    );
    uint256 tokensToClaim = users[msg.sender].tokenToClaim;
    users[msg.sender].tokenToClaim = 0;
    emit TokenClaimed(msg.sender, tokensToClaim);
    betToken.safeTransfer(msg.sender, tokensToClaim);
  }

  /**
   * @notice  Get the total number of tokens bet by a user.
   * @param   sessionId  .
   * @param   user  .
   * @return  uint256  .
   */
  function totalTokensBetPerSessionIdPerUser(bytes32 sessionId, address user)
    external
    view
    returns (uint256)
  {
    return users[user].totalTokensBetPerSessionId[sessionId];
  }

  /**
   * @notice  Get an array of session IDs.
   * @dev     Use range to avoid gas limit errors
   * @param   start  .
   * @param   end  .
   * @return  bytes32[]  .
   */
  function getBettingSessionIdsBySlice(uint256 start, uint256 end)
    external
    view
    returns (bytes32[] memory)
  {
    require(start < end, "BetManager: start must be smaller than end");
    require(
      end <= bettingSessionIds.length,
      "BetManager: end must be smaller than sessionIds.length"
    );
    bytes32[] memory sessionIdsSlice = new bytes32[](end - start);
    for (uint256 i = start; i < end; i++) {
      sessionIdsSlice[i - start] = bettingSessionIds[i];
    }
    return sessionIdsSlice;
  }

  /**
   * @notice   Return the number of session IDs.
   * @dev  Get the length of the session IDs array.
   * @return  uint256  .
   */
  function getSessionIdsLength() external view returns (uint256) {
    return bettingSessionIds.length;
  }

  /**
   * @notice  Get the number of tokens to claim for a user.
   * @param   user  User address.
   * @return  uint256  Total number of tokens to claim.
   */
  function getTokenToClaim(address user) external view returns (uint256) {
    return users[user].tokenToClaim;
  }

  /**
   * @notice  Generate a session ID.
   * @dev     The session ID is generated by hashing the twitter user ID, the start timestamp and the end timestamp.
   * @param   twitterUserId  .
   * @param   startTimestamp  .
   * @param   endTimestamp  .
   * @return  bytes32  Session ID (hash)
   */

  function generateSessionId(
    string calldata twitterUserId,
    uint256 startTimestamp,
    uint256 endTimestamp
  ) public pure returns (bytes32) {
    return
      keccak256(abi.encodePacked(twitterUserId, startTimestamp, endTimestamp));
  }

  /**
   * @notice  Checks if a twitter user ID is verified.
   * @param   twitterUserId  .
   * @return  bool  .
   */
  function isTwitterIdVerified(string calldata twitterUserId)
    public
    view
    returns (bool)
  {
    return verifiedTwitterUserIds[stringToTwitterId(twitterUserId)];
  }

  /**
   * @notice Records a bet bet by one user for a specified session.
   * @dev This function is used to record a bet by one user for a specified session. It also updates the user's units and total tokens bet. It also checks that the user has not exceeded the maximum tokens per session.
   * @param sessionId The unique ID of the session.
   * @param bet The amount of the bet.
   * @param user The address of the user making the bet.
   * @param tokenBetAmount The amount of tokens bet.
   */
  function recordOneUserBet(
    bytes32 sessionId,
    uint256 bet,
    address user,
    uint256 tokenBetAmount
  ) private {
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

  function distributeWinnerShares(
    uint256 tokensForWinner,
    address[] memory usersWhoWon
  ) private {
    // Distribute winner shares to winners
    uint256 tokensWon = tokensForWinner / usersWhoWon.length;
    for (uint256 i = 0; i < usersWhoWon.length; i++) {
      address user = usersWhoWon[i];
      users[user].tokenToClaim += tokensWon;
      users[user].totalTokensWon += tokensWon;
      users[user].totalBetWon += 1;
    }
  }

  /**
   * @notice  Calculates the shares of the total tokens to share.
   * @param   totalTokensToShare  Total tokens to share.
   * @return  tokensForWinner  Tokens for the winner.
   * @return  tokensForStacking  Tokens for stacking pool.
   * @return  tokensForBurn  Tokens to burn.
   * @return  tokensForTeam  Tokens for team.
   */
  function calculateShares(uint256 totalTokensToShare)
    private
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

  /**
   * @notice  Convert a string to a twitter ID (bytes32).
   * @dev     Usefull to compare 2 twitter ID in string format.
   * @param   source  .
   * @return  result  .
   */
  function stringToTwitterId(string memory source)
    private
    pure
    returns (bytes32 result)
  {
    result = keccak256(abi.encodePacked(source));
  }
}
