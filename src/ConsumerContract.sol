// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.16;

import "chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

/**
 * @title Consumer contract
 * @author Stake&Bet stakeandbet@proton.me
 * @notice This contract call the associated external adapter to retrieve a tweet count
 */
contract ConsumerContract is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    uint256 public tweetCount;
    string private jobId;
    uint256 private constant ORACLE_PAYMENT = 1 * LINK_DIVISIBILITY; // 1 * 10**18

    event TweetCountFullfilled(bytes32 indexed requestId, uint256 _tweetCount);

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8);
    }

    /**
     * @notice Sets the jobId for the Chainlink request.
     * @param newJobId The jobId for the Chainlink request.
     */
    function setJobId(string memory newJobId) public onlyOwner {
        jobId = newJobId;
    }

    /**
     * @notice Creates a Chainlink request to retrieve the number of tweets from the given parameters.
     * @param from The user to search for tweets.
     * @param startTime The UNIX timestamp from which the search begins.
     * @param endTime The UNIX timestamp at which the search ends.
     * @return requestId the request ID of the new Chainlink request.
     */
    function requestTweetCount(
        string memory from,
        uint256 startTime,
        uint256 endTime
    ) public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest( // Last Chainlink version use buildOperatorRequest instead
            stringToBytes32(jobId),
            address(this),
            this.fulfill.selector
        );

        req.add("from", from);
        req.addUint("start-time", startTime);
        req.addUint("end-time", endTime);
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
        emit TweetCountFullfilled(requestId, newTweetCount);
        tweetCount = newTweetCount;
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

    function stringToBytes32(
        string memory source
    ) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            // solhint-disable-line no-inline-assembly
            result := mload(add(source, 32))
        }
    }
}
