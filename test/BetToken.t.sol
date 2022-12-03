// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Test.sol";
import {BetToken} from "../src/BetToken.sol";

// Derive from original contract to access internal functions (mint) for testing
contract MintableBetToken is BetToken {
  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }
}

contract BetTokenTest is Test {
  address owner = address(0x1337);
  address account1 = address(0x1);
  address account2 = address(0x2);

  uint8 decimals = 6;

  MintableBetToken token;

  function setUp() public {
    vm.prank(owner);
    token = new MintableBetToken();
  }

  // -------------------- WHITELIST --------------------
  function test_initialContractState() public {
    assertEq(token.decimals(), decimals);
    assertEq(token.owner(), owner);
    assertTrue(token.isWhitelisted(owner));
  }

  function test_addToWhitelist() public {
    vm.prank(owner);
    token.addToWhitelist(account1);

    assertTrue(token.isWhitelisted(account1));
  }

  function test_removeFromWhitelist() public {
    vm.startPrank(owner);
    token.addToWhitelist(account1);

    token.removeFromWhitelist(account1);
    vm.stopPrank();

    assertFalse(token.isWhitelisted(account1));
  }

  // -------------------- TRANSFERS --------------------

  // Transfer should fail because none of the accounts are whitelisted
  function test_transferNotWhitelisted() public {
    _mintTokens(account1, 10000 * 10**decimals);
    vm.startPrank(account1);

    vm.expectRevert(
      "BetToken: Invalid transfer. Only whitelisted addresses or owner can send or receive tokens."
    );
    token.transfer(account2, 100 * 10**decimals);
    vm.stopPrank();
  }

  // Transfer should success because sender is whitelisted
  function test_transferSenderWhitelisted() public {
    _mintTokens(account1, 10000 * 10**decimals);
    vm.prank(owner);
    token.addToWhitelist(account1);

    vm.prank(account1);
    token.transfer(account2, 100 * 10**decimals);
  }

  // Transfer should success because recipient is whitelisted
  function test_transferRecipientWhitelisted() public {
    _mintTokens(account1, 10000 * 10**decimals);
    vm.prank(owner);
    token.addToWhitelist(account2);

    vm.prank(account1);
    token.transfer(account2, 100 * 10**decimals);
  }

  // Transfer should success because both sender and recipient are whitelisted
  function test_transferBothWhitelisted() public {
    _mintTokens(account1, 10000 * 10**decimals);
    _mintTokens(account2, 10000 * 10**decimals);
    vm.startPrank(owner);
    token.addToWhitelist(account1);
    token.addToWhitelist(account2);
    vm.stopPrank();

    vm.prank(account1);
    token.transfer(account2, 100 * 10**decimals);
    vm.prank(account2);
    token.transfer(account1, 100 * 10**decimals);
  }

  // -------------------- ADMIN --------------------
  function test_setNewOwner() public {
    address oldOwner = owner;
    address newOwner = address(0x1338);
    vm.startPrank(owner);

    assert(token.owner() == oldOwner);
    token.transferOwnership(newOwner);
    assert(token.owner() == newOwner);

    assertFalse(token.isWhitelisted(oldOwner));
    assertTrue(token.isWhitelisted(newOwner));
    vm.stopPrank();
  }

  // -------------------- HELPERS --------------------
  function _mintTokens(address account, uint256 amount) private {
    token.mint(account, amount);
  }
}
