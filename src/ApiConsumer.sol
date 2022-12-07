// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.16;

import "chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

import {BetManager} from "./BetManager.sol";

/**
 * @title Consumer contract
 * @author Stake&Bet stakeandbet@proton.me
 * @notice This contract call the associated external adapter to retrieve a tweet count
 */
contract ApiConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    BetManager public betManager;

    string public jobId;
    uint256 private constant ORACLE_PAYMENT = 1 * LINK_DIVISIBILITY; // 1 * 10**18

    event TweetCountFullfilled(
        bytes32 indexed requestId,
        bytes32 indexed sessionId,
        uint256 _tweetCount
    );

    mapping(bytes32 => uint256) public tweetCountPerSessionId;
    mapping(bytes32 => bytes32) public sessionIdPerRequestId;

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8);
    }

    /**
     * @notice Sets the jobId for the Chainlink request.
     * @param newJobId The jobId for the Chainlink request.
     */
    function setJobId(string memory newJobId) public onlyOwner {
        require(
            bytes(newJobId).length == 32,
            "JobId must be 32 characters length"
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
    ) public onlyOwner returns (bytes32 requestId) {
        require(startTime < endTime, "Start time can't be older than end time");
        // require(
        //     block.timestamp - uint256(startTime) > 7 days,
        //     "Start time can't be older than 7 days"
        // );
        require(bytes(from).length > 0, "Requested twitter ID can't be empty");
        sessionIdPerRequestId[requestId] = sessionId;
        Chainlink.Request memory req = buildChainlinkRequest( // Last Chainlink version use buildOperatorRequest instead
            stringToBytes32(jobId),
            address(this),
            this.fulfill.selector
        );

        req.add("from", from);
        req.addUint("startTime", startTime);
        req.addUint("endTime", endTime);
        // No need extra parameters for this job. Send the request
        return sendChainlinkRequest(req, ORACLE_PAYMENT); // Last Chainlink version use sendOperatorRequest instead
    }

    /**
     * @notice Fulfills the Chainlink request by storing the tweet count.
     * @param requestId The requestId of the Chainlink request.
     * @param newTweetCount The number of tweets retrieved.
     * */
    function fulfill(
        bytes32 requestId,
        uint256 newTweetCount
    ) public recordChainlinkFulfillment(requestId) {
        bytes32 sessionId = sessionIdPerRequestId[requestId];
        emit TweetCountFullfilled(
            requestId,
            sessionId,
            newTweetCount
        );
        tweetCountPerSessionId[
            sessionId
        ] = newTweetCount;
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
    function contractBalances()
        public
        view
        returns (uint256 eth, uint256 link)
    {
        eth = address(this).balance;

        LinkTokenInterface linkContract = LinkTokenInterface(
            chainlinkTokenAddress()
        );
        link = linkContract.balanceOf(address(this));
    }

    /**
     *   @notice Allows the owner to withdraw LINK tokens
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    /**
     *   @notice Allows the owner to withdraw ETH
     */
    function withdrawBalance() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // function stringToBytes32(
    //     string memory source
    // ) private pure returns (bytes32 result) {
    //     bytes memory tempEmptyStringTest = bytes(source);
    //     if (tempEmptyStringTest.length == 0) {
    //         return 0x0;
    //     }

    //     assembly {
    //         // solhint-disable-line no-inline-assembly
    //         result := mload(add(source, 32))
    //     }
    // }

    // This function takes a string and returns a bytes32 representation of it.
    function stringToBytes32(
        string memory input
    ) public pure returns (bytes32) {
        bytes32 stringInBytes32 = bytes32(bytes(input));
        return stringInBytes32;
    }

    function setBetManagerContract(address _betManager) public onlyOwner {
        require(_betManager != address(0), "BetManager address can't be 0x0");
        betManager = BetManager(_betManager);
    }
}
