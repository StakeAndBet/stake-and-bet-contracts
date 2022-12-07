// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ApiConsumer} from "../src/ApiConsumer.sol";

contract ApiConsumerTest is Test {
    address owner = address(0x1337);

    ApiConsumer consumer;
    IERC20 linkToken;
    string jobId;
    address linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address oracleAdress = 0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8;
    bytes32 dummyRequestId = uint256ToBytes32(1337);

    uint32 RIGHT_START_TIMESTAMP =
        uint32(block.timestamp - (block.timestamp % 1 days) - 1 days);
    // MAKE A FUNCTION IN CONSUMER (RENAME IT APICONSUMER) THAT GIVE THE STARTING DAY TIMESTAMP

    event TweetCountFullfilled(bytes32 indexed requestId, uint256 _tweetCount);
    event ChainlinkRequested(bytes32 indexed id);

    function setUp() public {
        linkToken = IERC20(linkAddress);
        vm.startPrank(owner);
        consumer = new ApiConsumer();
        // consumer = ConsumerContract(0x6412d81226ACED3c25db8f8D59B2Ad3E3Fb74E0d);
        vm.stopPrank();
        vm.startPrank(0xE4dDb4233513498b5aa79B98bEA473b01b101a67);
        linkToken.transfer(
            address(consumer),
            linkToken.balanceOf(0xE4dDb4233513498b5aa79B98bEA473b01b101a67)
        );
        vm.stopPrank();
    }

    function test_initialContractState() public {
        assertEq(consumer.jobId(), "");
    }

    function test_setJobId() public {
        vm.startPrank(owner);
        vm.expectRevert("JobId must be 32 characters length");
        consumer.setJobId("wrongJobId");
        consumer.setJobId("RightJobIdWhoIs32CharacterLength");
        assertEq(consumer.jobId(), "RightJobIdWhoIs32CharacterLength");
        vm.stopPrank();
    }

    // Should emit an event ChainlinkRequested with the request ID
    // function test_requestTweetCount() public {
    //     vm.expectRevert("Only callable by owner");
    //     consumer.requestTweetCount("elonmusk", 1670348221, 1670348222);
    //     vm.startPrank(owner);
    //     consumer.setJobId("a7e91a606f54485cb6ce7749ffa2478a");
    //     vm.expectRevert("Start time can't be older than end time");
    //     consumer.requestTweetCount("elonmusk", 1670348221, 1000348222);
    //     // vm.expectRevert("Start time can't be older than 7 days");
    //     // consumer.requestTweetCount("elonmusk", 1669590089, 1670348221);
    //     consumer.requestTweetCount("elonmusk", 1670348221, 1670348222);
    //     vm.expectEmit(false, false, false, true);
    //     emit ChainlinkRequested(dummyRequestId);
    //     consumer.requestTweetCount("elonmusk", 1670348221, 1670348222);
    //     vm.stopPrank();
    // }

    // =========== UTILITY ========== //

    // function toBytes(uint256 x) public pure returns (bytes memory b) {
    //     b = new bytes(32);
    //     assembly {
    //         mstore(add(b, 32), x)
    //     }
    // }

    // This function takes a uint256 value and returns a bytes32 representation of it.
    function uint256ToBytes32(uint256 _value) public pure returns (bytes32) {
        // Split the value into four 8-byte parts
        uint256 part1 = _value & 0xFFFFFFFF;
        uint256 part2 = (_value >> 32) & 0xFFFFFFFF;
        uint256 part3 = (_value >> 64) & 0xFFFFFFFF;
        uint256 part4 = (_value >> 96) & 0xFFFFFFFF;

        // Pack those parts into a single bytes32
        bytes32 result = bytes32(part1) |
            bytes32(part2 << 8) |
            bytes32(part3 << 16) |
            bytes32(part4 << 24);

        return result;
    }
}
