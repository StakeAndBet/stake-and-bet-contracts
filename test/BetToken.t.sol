// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {BetToken} from "../src/BetToken.sol";

contract BetTokenTest is Test {
  BetToken token;

  function setUp() public {
    token = new BetToken();
  }

  // -------------------- WHITELIST --------------------
  function test_initialContractState() public {
    // Check that the owner is whitelisted
    assertTrue(token.owner() == address(this));
    assertTrue(token.isWhitelisted(address(this)));
  }

  function test_addToWhitelist() public {
    address account = address(0x1);
    token.addToWhitelist(account);
    assertTrue(token.isWhitelisted(account));
  }

  function test_removeFromWhitelist() public {
    address account = address(0x1);
    token.addToWhitelist(account);
    assertTrue(token.isWhitelisted(account));
    token.removeFromWhitelist(account);
    assertTrue(!token.isWhitelisted(account));
  }
}
