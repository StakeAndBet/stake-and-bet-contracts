// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.16;

import "chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "openzeppelin-contracts/access/AccessControl.sol";
// import "chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

import {BetManager} from "./BetManager.sol";

/**
 * @title Consumer contract
 * @author Stake&Bet stakeandbet@proton.me
 * @notice This contract call the associated external adapter to retrieve a tweet count
 */
contract ApiConsumer is ChainlinkClient, AccessControl {
  /// -----------------------------------------------------------------------
  /// Library usage
  /// -----------------------------------------------------------------------
  using Chainlink for Chainlink.Request;

  /// -----------------------------------------------------------------------
  /// Constants
  /// -----------------------------------------------------------------------
  address public constant chainlinkOracleAddr =
    0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8; // TODO: Dynamic oracle address

  bytes32 public constant TWEET_COUNT_REQUESTER_ROLE =
    keccak256("TWEET_COUNT_REQUESTER_ROLE");

  uint256 private constant ORACLE_PAYMENT = (1 * LINK_DIVISIBILITY) / 10; // 1 * 10**18 / 10
  BetManager public betManager;

  /// -----------------------------------------------------------------------
  /// Storage variables
  /// -----------------------------------------------------------------------

  string public jobId;
  mapping(bytes32 => bytes32) public sessionIdPerRequestId;
  mapping(bytes32 => uint256) public tweetCountPerSessionId;

  /// -----------------------------------------------------------------------
  /// Events
  /// -----------------------------------------------------------------------
  event TweetCountFullfilled(
    bytes32 indexed requestId,
    bytes32 indexed sessionId,
    uint256 tweetCount
  );
  event NewBetManager(address oldBetManager, address newBetManager);
  event NewJobId(string oldJobId, string newJobId);

  constructor() {
    setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
    setChainlinkOracle(0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8);
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /**
   * @notice Sets the jobId for the Chainlink request.
   * @param newJobId The jobId for the Chainlink request.
   */
  function setJobId(string memory newJobId)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(
      bytes(newJobId).length == 32,
      "ApiConsumer: JobId must be 32 characters length"
    );
    string memory oldJobId = jobId;
    emit NewJobId(oldJobId, newJobId);
    jobId = newJobId;
  }

  /**
   * @notice Creates a Chainlink request to retrieve the number of tweets from the given parameters.
   * @param sessionId The session ID of the beting session.
   * @param from The user to search for tweets.
   * @param startTime The UNIX timestamp (GMT) from which the search begins.
   * @param endTime The UNIX timestamp (GMT) at which the search ends.
   * @dev uint32 is sufficient to hold a date in UNIX Timestamp format until Feb 07 2106
   * @return requestId the request ID of the new Chainlink request.
   */
  function requestTweetCount(
    bytes32 sessionId,
    string memory from,
    uint32 startTime,
    uint32 endTime
  ) external onlyRole(TWEET_COUNT_REQUESTER_ROLE) returns (bytes32) {
    require(
      startTime < endTime,
      "ApiConsumer: Start time can't be older than end time"
    );
    require(
      startTime % 1 days == 0,
      "ApiConsumer: Start timestamp must be at the beginning of a day"
    );
    require(
      uint32(block.timestamp - 7 days) <= startTime,
      "ApiConsumer: Start time can't be older than 7 days"
    );
    require(
      bytes(from).length > 0,
      "ApiConsumer: Requested twitter ID can't be empty"
    );
    Chainlink.Request memory req = buildChainlinkRequest(
      _stringToBytes32(jobId),
      address(this),
      this.fulfill.selector
    );
    req.add("from", from);
    req.addUint("startTime", startTime);
    req.addUint("endTime", endTime);
    bytes32 requestId = sendChainlinkRequest(req, ORACLE_PAYMENT);
    sessionIdPerRequestId[requestId] = sessionId;
    return requestId;
  }

  /**
   * @notice Oracle fulfills the Chainlink request by storing the tweet count for the given session ID,
   * then calling the BetManager to settle the session.
   * @param requestId The requestId of the Chainlink request.
   * @param newTweetCount The number of tweets retrieved.
   * */
  function fulfill(bytes32 requestId, uint256 newTweetCount)
    external
    recordChainlinkFulfillment(requestId)
  {
    bytes32 sessionId = sessionIdPerRequestId[requestId];
    emit TweetCountFullfilled(
      requestId,
      sessionId,
      tweetCountPerSessionId[requestId]
    );
    tweetCountPerSessionId[sessionId] = newTweetCount;
    // CALL BETMANAGER

    bool success = betManager.settleBettingSession(sessionId, newTweetCount);
    require(success, "BetManager failed to settle session");
  }

  /**
   * @notice Sets the BetManager address and give it the TWEET_COUNT_REQUESTER_ROLE.
   * @param newBetManager The new address of the BetManager.
   */
  function setBetManager(address newBetManager)
    external
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(
      newBetManager != address(0),
      "ApiConsumer: BetManager address can't be 0x0"
    );
    require(
      newBetManager != address(betManager),
      "ApiConsumer: BetManager address must be different from current one"
    );

    address oldBetManager = address(betManager);
    _revokeRole(TWEET_COUNT_REQUESTER_ROLE, oldBetManager);
    betManager = BetManager(newBetManager);
    grantRole(TWEET_COUNT_REQUESTER_ROLE, newBetManager);
    emit NewBetManager(oldBetManager, newBetManager);
  }

  /**
   * @notice Allows the owner to withdraw LINK tokens
   */
  function withdrawLink() external onlyRole(DEFAULT_ADMIN_ROLE) {
    LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
    require(
      link.transfer(msg.sender, link.balanceOf(address(this))),
      "ApiConsumer: Unable to transfer"
    );
  }

  /**
   * @notice Returns the contract LINK balance.
   * @return link The LINK balance of the contract.
   */
  function contractLinkBalance() external view returns (uint256 link) {
    LinkTokenInterface linkContract = LinkTokenInterface(
      chainlinkTokenAddress()
    );
    link = linkContract.balanceOf(address(this));
  }

  /**
   * @notice This function converts a string to a bytes32 data type
   * @param input String to be converted
   * @return Returns a bytes32 data type
   */
  function _stringToBytes32(string memory input)
    internal
    pure
    returns (bytes32)
  {
    bytes32 stringInBytes32 = bytes32(bytes(input));
    return stringInBytes32;
  }
}
