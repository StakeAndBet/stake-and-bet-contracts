// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

// The purpose of this contract is to provide a simple way to swap between
// two tokens. It is not meant to be used as a liquidity pool, but rather
// as a way to swap between two tokens.

// The contract is designed to be used with the BetToken contract, but
// can be used with any ERC20 token.

// It is assumed that the two tokens have the same number of decimals.

// The contract has the following features:
// - 5:1 swap ratio between BetToken and the other token
// - User can deposit any amount of the other token and receive the same amount of BetToken minted to their account.
// - User can deposit any amount of BetToken and receive the same amount of the other token sent to their account. The BetToken is burned.

import {BetToken} from "./BetToken.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

contract BetStableSwap {
  using SafeERC20 for IERC20;
  using SafeERC20 for BetToken;

  BetToken public betToken;
  IERC20 public stableToken;

  // 1 StableToken = 5 BetToken
  uint256 public constant SWAP_RATIO = 5;

//   event SwappedStableTokenToBetToken(address indexed user, uint256 amount);
//   event SwappedBetTokenToStableToken(address indexed user, uint256 amount);

  constructor(BetToken _betToken, IERC20 _stableToken) {
    betToken = _betToken;
    stableToken = _stableToken;
  }

  /**
   * @dev Transfers `amount` of stable tokens from the msg.sender to this contract and mints the corresponding amount of betting tokens
   * @notice This function is used to make deposits of stable tokens in exchange for betting tokens
   * @param amount uint256 The amount of stable tokens to deposit
   */
  function depositStableTokenForBetToken(uint256 amount) external {
    require(amount > 0, "BetStableSwap: Amount must be greater than 0");
    // emit SwappedStableTokenToBetToken(msg.sender, amount);
    stableToken.safeTransferFrom(msg.sender, address(this), amount);
    betToken.mint(msg.sender, amount * SWAP_RATIO);
  }

  /**
   * @dev Burn `amount` of bet tokens from the msg.sender to this contract and sends the corresponding amount of stable tokens to the msg.sender
   * @notice This function is used to withdraw stable tokens in exchange for betting tokens
   * @param amount uint256 The amount of stable tokens to deposit
   */
  function burnBetTokenForStableToken(uint256 amount) external {
    require(amount > 0, "BetStableSwap: Amount must be greater than 0");
    // emit SwappedBetTokenToStableToken(msg.sender, amount);
    betToken.burnFrom(msg.sender, amount);
    stableToken.safeTransfer(msg.sender, amount / 5);
  }
}
