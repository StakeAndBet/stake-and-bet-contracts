// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.16;

import "chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/access/AccessControl.sol";
// import "chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

import {BetManager} from "./BetManager.sol";

/**
 * @title Consumer contract
 * @author Stake&Bet stakeandbet@proton.me
 * @notice This contract call the associated external adapter to retrieve a tweet count
 */
contract ApiConsumer is ChainlinkClient, AccessControl, Ownable {
  using Chainlink for Chainlink.Request;

  BetManager public betManager;

  address public chainlinkOracleAddr =
    0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8;

  string public jobId;
  uint256 private constant ORACLE_PAYMENT = (1 * LINK_DIVISIBILITY) / 10; // 1 * 10**18 / 10

  mapping(bytes32 => bytes32) public sessionIdPerRequestId;
  mapping(bytes32 => uint256) public tweetCountPerSessionId;

  bytes32 public constant TWEET_COUNT_REQUESTER_ROLE =
    keccak256("TWEET_COUNT_REQUESTER_ROLE");

  event TweetCountFullfilled(
    bytes32 indexed requestId,
    bytes32 indexed sessionId,
    uint256 _tweetCount
  );
  event NewBetManager(address oldBetManager, address newBetManager);

  constructor() {
    setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
    setChainlinkOracle(chainlinkOracleAddr);
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /**
   * @notice Sets the jobId for the Chainlink request.
   * @param newJobId The jobId for the Chainlink request.
   */
  function setJobId(string memory newJobId)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(
      bytes(newJobId).length == 32,
      "ApiConsumer: JobId must be 32 characters length"
    );
    jobId = newJobId;
  }

  /**
   * @notice Creates a Chainlink request to retrieve the number of tweets from the given parameters.
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
  ) public onlyRole(TWEET_COUNT_REQUESTER_ROLE) returns (bytes32) {
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
   * @notice Fulfills the Chainlink request by storing the tweet count.
   * @param requestId The requestId of the Chainlink request.
   * @param newTweetCount The number of tweets retrieved.
   * */
  function fulfill(bytes32 requestId, uint256 newTweetCount)
    public
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

    bool success = betManager.settleSession(sessionId, newTweetCount);
    require(success, "BetManager failed to settle session");
  }

  /*
    ========= UTILITY FUNCTIONS ==========
    */

  /**
   * @notice Returns the contract ETH and LINK balances.
   * @return eth The ETH balance of the contract.
   * @return link The LINK balance of the contract.
   */
  function contractBalances() public view returns (uint256 eth, uint256 link) {
    eth = address(this).balance;

    LinkTokenInterface linkContract = LinkTokenInterface(
      chainlinkTokenAddress()
    );
    link = linkContract.balanceOf(address(this));
  }

  /**
   *   @notice Allows the owner to withdraw LINK tokens
   */
  function withdrawLink() public onlyRole(DEFAULT_ADMIN_ROLE) {
    LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
    require(
      link.transfer(msg.sender, link.balanceOf(address(this))),
      "ApiConsumer: Unable to transfer"
    );
  }

  /**
   *   @notice Allows the owner to withdraw ETH
   */
  function withdrawBalance(address payable to)
    public
    payable
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    // Call returns a boolean value indicating success or failure.
    // This is the current recommended method to use.
    (bool sent, ) = to.call{value: msg.value}("");
    require(sent, "ApiConsumer: Failed to send Ether");
  }

  // SLITHER NOT OK WITH onlyRole(DEFAULT_ADMIN_ROLE)

  function setBetManager(address newBetManager)
    public
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

  // This function takes a string and returns a bytes32 representation of it.
  function _stringToBytes32(string memory input)
    internal
    pure
    returns (bytes32)
  {
    bytes32 stringInBytes32 = bytes32(bytes(input));
    return stringInBytes32;
  }
}
