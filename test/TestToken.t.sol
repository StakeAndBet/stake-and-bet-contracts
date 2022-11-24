// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {TestToken} from "../src/TestToken.sol";

contract TestTokenTest is Test {
  TestToken token;

  function setUp() public {
    token = new TestToken();
  }

  function testAssertTrue() public {
    assertTrue(true);
  }
}
