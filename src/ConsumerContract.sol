// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.16;

import "chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract ConsumerContract is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    uint256 public tweetCount;
    string private jobId;
    uint256 private constant ORACLE_PAYMENT = 1 * LINK_DIVISIBILITY; // 1 * 10**18

    event tweetCountFullfilled(bytes32 indexed requestId, uint256 _tweetCount);

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8);
    }

    /* Create a Chainlink request to retrieve API response */

    /* Modify the jobId to call */
    function setJobId(string memory _jobId) public onlyOwner {
        jobId = _jobId;
    }

    function requestTweetCount(
        string memory _from
    ) public returns (bytes32 _requestId) {
        Chainlink.Request memory req = buildChainlinkRequest( // Last Chainlink version use buildOperatorRequest instead
            stringToBytes32(jobId),
            address(this),
            this.fulfill.selector
        );

        req.add("from", _from);
        // No need extra parameters for this job. Send the request
        return sendChainlinkRequest(req, ORACLE_PAYMENT); // Last Chainlink version use sendOperatorRequest instead
    }

    /* Receive the responses in the form of uint256 */
    function fulfill(
        bytes32 _requestId,
        uint256 _tweetCount
    ) public recordChainlinkFulfillment(_requestId) {
        emit tweetCountFullfilled(_requestId, _tweetCount);
        tweetCount = _tweetCount;
    }

    /*
    ========= UTILITY FUNCTIONS ==========
    */

    /**
     * Return the contract ETH and LINK balances
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
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

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
