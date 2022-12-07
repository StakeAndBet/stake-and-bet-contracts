// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract BetToken is ERC20PresetMinterPauser, Ownable {
  // Transfer whitelist
  mapping(address => bool) private whitelist;

  event AddedToWhitelist(address indexed account);
  event RemovedFromWhitelist(address indexed account);

  constructor() ERC20PresetMinterPauser("Stake & Bet Token", "SAB") {}

  /**
   * @notice Checks if the `from` or `to` addresses of the transfer are whitelisted/owner before the transfer is executed
   * @dev This function is called by the transfer and transferFrom functions before the actual transfer is executed. If either address is not whitelisted or the owner, the transfer is reverted.
   Calling conditions:
      - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
      will be transferred to `to`.
      - when `from` is zero, `amount` tokens will be minted for `to`.
      - when `to` is zero, `amount` of ``from``'s tokens will be burned.
      - `from` and `to` are never both zero.
   * @param from Address from which the tokens are sent
   * @param to Address to which the tokens are sent
   * @param amount Amount of tokens to be sent
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);
    if (from != address(0) && to != address(0)) {
      require(
        isWhitelisted(from) || isWhitelisted(to),
        "BetToken: Invalid transfer. Only whitelisted addresses or owner can send or receive tokens."
      );
    }
  }

  /**
   * @notice Adds an address to the whitelist
   * @dev This function can only be called by the owner of the contract
   * @param addr Address to be added to the whitelist
   */
  function addToWhitelist(address addr) public onlyOwner {
    whitelist[addr] = true;
    emit AddedToWhitelist(addr);
  }

  /**
   * @notice Removes an address from the whitelist
   * @param addr Address to remove from the whitelist
   * @dev This function can only be called by the owner of the contract
   */
  function removeFromWhitelist(address addr) public onlyOwner {
    whitelist[addr] = false;
    emit RemovedFromWhitelist(addr);
  }

  /// @notice Checks if an address is whitelisted
  /// @param addr The address to check
  /// @return bool Returns true if the address is whitelisted or owner, false otherwise
  function isWhitelisted(address addr) public view returns (bool) {
    return whitelist[addr] || addr == owner();
  }
}
