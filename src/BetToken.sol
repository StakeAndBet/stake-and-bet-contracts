// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract BetToken is ERC20, Ownable {
  // Transfer whitelist
  mapping(address => bool) private whitelist;

  event WhitelistAdded(address indexed account);
  event WhitelistRemoved(address indexed account);

  constructor() ERC20("Stake & Bet Token", "SAB") {
    whitelist[owner()] = true;
  }

  /**
   * @notice Checks if the `from` or `to` addresses of the transfer are whitelisted before the transfer is executed
   * @param from Address from which the tokens are sent
   * @param to Address to which the tokens are sent
   * @param amount Amount of tokens to be sent
   * @dev This function is called by the transfer and transferFrom functions before the actual transfer is executed. If either address is not whitelisted, the transfer is not allowed.
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual override {
    super._beforeTokenTransfer(from, to, amount);
    require(
      whitelist[from] || whitelist[to],
      "BetToken: Invalid transfer. Only whitelisted _addresses can send/receive tokens."
    );
  }

  /**
   * @notice Adds an address to the whitelist
   * @dev This function can only be called by the owner of the contract
   * @param _address Address to be added to the whitelist
   */
  function addToWhitelist(address _address) public onlyOwner {
    whitelist[_address] = true;
    emit WhitelistAdded(_address);
  }

  /**
   * @notice Removes an address from the whitelist
   * @param _address Address to remove from the whitelist
   * @dev This function can only be called by the owner of the contract
   */
  function removeFromWhitelist(address _address) public onlyOwner {
    whitelist[_address] = false;
    emit WhitelistRemoved(_address);
  }

  /**
   * @notice Change the owner of the contract
   * @dev Ensure that the old owner is removed from the whitelist and the new owner is added to the whitelist
   * @param _newOwner The new owner of the contract.
   */
  function setNewOwner(address _newOwner) external onlyOwner {
    removeFromWhitelist(owner());
    transferOwnership(_newOwner);
    addToWhitelist(_newOwner);
  }

  /// @notice Checks if an address is whitelisted
  /// @param _address The address to check
  /// @return bool Returns true if the address is whitelisted, false otherwise
  function isWhitelisted(address _address) public view returns (bool) {
    return whitelist[_address];
  }
}
