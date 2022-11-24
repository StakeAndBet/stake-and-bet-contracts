// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {BetToken} from "../src/BetToken.sol";

contract BetTokenTest is Test {
  BetToken token;

  function setUp() public {
    token = new BetToken();
  }

  function testAssertTrue() public {
    assertTrue(true);
  }
}
