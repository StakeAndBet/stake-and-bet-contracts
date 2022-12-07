// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {ApiConsumer} from "../src/ApiConsumer.sol";
import {BetManager} from "../src/BetManager.sol";

// Derive from original contract to access internal function (stringToBytes32)
contract DerivedApiConsumer is ApiConsumer {
    function stringToBytes32(
        string memory input
    ) public pure returns (bytes32 output) {
        output = _stringToBytes32(input);
    }
}

contract ApiConsumerTest is Test {
    address admin = address(0x1337);
    address betManagerAddress = address(0x42);
    address randomUser = address(0x123456789);

    address linkAddress = 0x326C977E6efc84E512bB9C30f76E30c160eD06FB;
    address oracleAdress = 0xBb3875718A107B7fcC04935eB7e3fFb26820E0B8;

    ApiConsumer apiConsumer;
    DerivedApiConsumer derivedApiConsumer;
    BetManager betManager;

    IERC20 linkToken;
    string jobId;

    bytes32 dummyRequestId = uint256ToBytes32(1337);
    bytes32 dummySessionId = uint256ToBytes32(42);
    uint256 dummyTweetCount = 1337;

    uint32 RIGHT_START_TIMESTAMP =
        getDayStartingTimestamp(uint32(block.timestamp - 1 days));
    uint32 RIGHT_END_TIMESTAMP =
        RIGHT_START_TIMESTAMP + uint32(1 days - 1 seconds);

    uint32 TOO_OLD_START_TIMESTAMP =
        getDayStartingTimestamp(uint32(block.timestamp - 7 days - 1 seconds));

    event TweetCountFullfilled(
        bytes32 indexed requestId,
        bytes32 indexed sessionId,
        uint256 _tweetCount
    );
    event ChainlinkRequested(bytes32 indexed id);

    function setUp() public {
        linkToken = IERC20(linkAddress);
        vm.startPrank(admin);
        // consumer = ConsumerContract(0x6412d81226ACED3c25db8f8D59B2Ad3E3Fb74E0d);
        apiConsumer = new ApiConsumer();
        vm.stopPrank();
        vm.startPrank(0xE4dDb4233513498b5aa79B98bEA473b01b101a67);
        linkToken.transfer(
            address(apiConsumer),
            linkToken.balanceOf(0xE4dDb4233513498b5aa79B98bEA473b01b101a67)
        );
        vm.stopPrank();
    }

    function test_initialContractState() public {
        assertEq(apiConsumer.jobId(), "");
        assertTrue(
            apiConsumer.hasRole(apiConsumer.DEFAULT_ADMIN_ROLE(), admin)
        );
    }

    function test_setJobIdShouldRevert() public {
        vm.startPrank(admin);
        vm.expectRevert("ApiConsumer: JobId must be 32 characters length");
        apiConsumer.setJobId("wrongJobId");
        vm.stopPrank();
    }

    function test_setJobId() public {
        vm.startPrank(admin);
        apiConsumer.setJobId("RightJobIdWhoIs32CharacterLength");
        assertEq(apiConsumer.jobId(), "RightJobIdWhoIs32CharacterLength");
        vm.stopPrank();
    }

    function test_setBetManagerShouldRevert() public {
        vm.startPrank(admin);
        vm.expectRevert("ApiConsumer: BetManager address can't be 0x0");
        apiConsumer.setBetManager(address(0));
        apiConsumer.setBetManager(betManagerAddress);
        assertEq(address(apiConsumer.betManager()), betManagerAddress);
        vm.expectRevert(
            "ApiConsumer: BetManager address must be different from current one"
        );
        apiConsumer.setBetManager(betManagerAddress);
        vm.stopPrank();
    }

    function test_stringToBytes32() public {
        vm.startPrank(admin);
        apiConsumer = new ApiConsumer();
        derivedApiConsumer = new DerivedApiConsumer();
        assertEq(
            derivedApiConsumer.stringToBytes32(
                "RightJobIdWhoIs32CharacterLength"
            ),
            0x52696768744a6f62496457686f497333324368617261637465724c656e677468
        );
    }

    function test_witdrawBalanceShouldRevert() public {
        vm.startPrank(randomUser);
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000123456789 is missing role 0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        apiConsumer.withdrawBalance(payable(msg.sender));
        vm.stopPrank();
    }

    function test_requestTweetCountWrongRoleShouldRevert() public {
        vm.startPrank(admin);
        vm.expectRevert(
            "AccessControl: account 0x0000000000000000000000000000000000001337 is missing role 0x9436e2c6939e447cd830de3602a218008f7b391f4932e1d3a92ab54049090092"
        );
        apiConsumer.requestTweetCount(
            dummySessionId,
            "elonmusk",
            RIGHT_START_TIMESTAMP,
            RIGHT_END_TIMESTAMP
        );
        vm.stopPrank();
    }

    function test_requestTweetCountShouldRevert() public {
        vm.prank(admin);
        apiConsumer.setBetManager(betManagerAddress);
        vm.startPrank(betManagerAddress);
        vm.expectRevert("ApiConsumer: Start time can't be older than end time");
        apiConsumer.requestTweetCount(
            dummySessionId,
            "elonmusk",
            RIGHT_END_TIMESTAMP,
            RIGHT_START_TIMESTAMP
        );
        vm.expectRevert(
            "ApiConsumer: Start timestamp must be at the beginning of a day"
        );
        apiConsumer.requestTweetCount(
            dummySessionId,
            "elonmusk",
            RIGHT_START_TIMESTAMP + 1 seconds,
            RIGHT_END_TIMESTAMP
        );
        vm.expectRevert("ApiConsumer: Start time can't be older than 7 days");
        apiConsumer.requestTweetCount(
            dummySessionId,
            "elonmusk",
            TOO_OLD_START_TIMESTAMP,
            TOO_OLD_START_TIMESTAMP + uint32(1 days - 1 seconds)
        );
        vm.expectRevert("ApiConsumer: Requested twitter ID can't be empty");
        apiConsumer.requestTweetCount(
            dummySessionId,
            "",
            RIGHT_START_TIMESTAMP,
            RIGHT_END_TIMESTAMP
        );
        vm.stopPrank();
    }

    // Should emit an event ChainlinkRequested with the request ID, and store the session ID in the mapping
    function test_requestTweetCountEvent() public {
        vm.startPrank(admin);
        apiConsumer.setJobId("a7e91a606f54485cb6ce7749ffa2478a");
        apiConsumer.setBetManager(betManagerAddress);
        vm.stopPrank();
        vm.startPrank(betManagerAddress);
        vm.expectEmit(false, false, false, true);
        emit ChainlinkRequested(dummyRequestId);
        apiConsumer.requestTweetCount(
            dummySessionId,
            "elonmusk",
            RIGHT_START_TIMESTAMP,
            RIGHT_END_TIMESTAMP
        );
        // TODO : check that the session ID is stored in the mapping, but request ID unkown ?
        vm.stopPrank();
    }

    function test_fulfillShouldRevert() public {
        vm.startPrank(admin);
        vm.expectRevert("Source must be the oracle of the request");
        apiConsumer.fulfill(dummyRequestId, dummyTweetCount);
        vm.stopPrank();
    }

    // =========== UTILITY ========== //

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

    // This function return the start of the day of the given timestamp
    function getDayStartingTimestamp(
        uint32 timestamp
    ) internal pure returns (uint32) {
        return timestamp - (timestamp % uint32(1 days));
    }
}
