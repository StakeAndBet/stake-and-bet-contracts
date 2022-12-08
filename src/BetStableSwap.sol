// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {BetToken} from "./BetToken.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @author  stakeandbet@proton.me
 * @title   BetStableSwap
 * @notice The purpose of this contract is to provide a simple way to swap between
 * two tokens. It is not meant to be used as a liquidity pool, but rather
 * as a way to swap between two tokens.
 * @dev  The contract is designed to be used with the BetToken contract, but
 * can be used with any ERC20 token.
 * The contract has the following features:
 *     - 5:1 swap ratio between BetToken and the other token
 *     - User can deposit any amount of the other token and receive the amount * 5 of BetToken minted to their account.
 *     - User can deposit any amount of BetToken and receive the amount / 5 of the other token sent to their account. The BetToken is burned.
 */
contract BetStableSwap {
  /// -----------------------------------------------------------------------
  /// Library usage
  /// -----------------------------------------------------------------------
  using SafeERC20 for IERC20;
  using SafeERC20 for BetToken;

  /// -----------------------------------------------------------------------
  /// Constants
  /// -----------------------------------------------------------------------
  uint256 public constant SWAP_RATIO = 5; // 1 StableToken = 5 BetToken

  /// -----------------------------------------------------------------------
  /// Storage variables
  /// -----------------------------------------------------------------------
  BetToken public betToken;
  IERC20 public stableToken; // The other token that can be swapped for BetToken

  constructor(address _betToken, address _stableToken) {
    require(
      _betToken != address(0),
      "BetStableSwap: BetToken address must be non-zero"
    );
    require(
      _stableToken != address(0),
      "BetStableSwap: StableToken address must be non-zero"
    );
    betToken = BetToken(_betToken);
    stableToken = IERC20(_stableToken);
  }

  /*
   * @dev Transfers `amount` of stable tokens from the msg.sender to this contract and mints the corresponding amount of betting tokens
   * @notice This function is used to make deposits of stable tokens in exchange for betting tokens
   * @param amount uint256 The amount of stable tokens to deposit
   */
  function depositStableTokenForBetToken(uint256 amount) external {
    require(amount > 0, "BetStableSwap: Amount must be greater than 0");
    stableToken.safeTransferFrom(msg.sender, address(this), amount);
    betToken.mint(msg.sender, amount * SWAP_RATIO);
  }

  /**
   * @dev Burn `amount` of bet tokens from the msg.sender to this contract and sends the corresponding amount of stable tokens to the msg.sender
   * @notice This function is used to withdraw stable tokens in exchange for betting tokens
   * @param amount uint256 The amount of stable tokens to deposit
   */
  function burnBetTokenForStableToken(uint256 amount) external {
    require(
      amount > SWAP_RATIO,
      "BetStableSwap: Amount must be greater than SWAP_RATIO"
    );
    betToken.burnFrom(msg.sender, amount);
    stableToken.safeTransfer(msg.sender, amount / SWAP_RATIO);
  }
}
