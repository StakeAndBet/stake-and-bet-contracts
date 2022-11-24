// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
  constructor() ERC20("Stake & Bet Token", "SAB") {
    _mint(msg.sender, 1000000000000000000000000);
  }
}