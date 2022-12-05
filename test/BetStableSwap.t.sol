pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {BetToken} from "../src/BetToken.sol";
import {BetStableSwap} from "../src/BetStableSwap.sol";

contract DummyStableToken is ERC20 {
  constructor() ERC20("Dummy Stable Token", "DST") {}

  function decimals() public pure override returns (uint8) {
    return 6;
  }

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }
}

contract BetStableSwapTest is Test {
  address betTokenOwner = address(0x1337);
  address betStableSwapOwner = address(0x1337);
  address stableTokenOwner = address(this);
  address account1 = address(0x1);
  address account2 = address(0x2);

  BetToken betToken;
  BetStableSwap betStableSwap;
  DummyStableToken stableToken;

  uint8 decimals = 6;

  //   event SwappedStableTokenToBetToken(address indexed user, uint256 amount);
  //   event SwappedBetTokenToStableToken(address indexed user, uint256 amount);

  function setUp() public {
    vm.prank(stableTokenOwner);
    stableToken = new DummyStableToken();

    vm.prank(betTokenOwner);
    betToken = new BetToken();

    vm.prank(betStableSwapOwner);
    betStableSwap = new BetStableSwap(betToken, stableToken);

    vm.startPrank(betTokenOwner);
    betToken.grantRole(betToken.MINTER_ROLE(), address(betStableSwap));
    vm.stopPrank();
  }

  function test_initialContractState() public {
    assertEq(address(betStableSwap.betToken()), address(betToken));
    assertEq(address(betStableSwap.stableToken()), address(stableToken));
  }

  function test_depositStableTokenForBetToken(uint256 amount) public {
    vm.assume(
      amount > 0 && amount <= type(uint256).max / betStableSwap.SWAP_RATIO()
    );
    _mintStableToken(account1, amount);

    vm.startPrank(account1);
    stableToken.approve(address(betStableSwap), amount);
    uint256 betTokenSupplyBefore = betToken.totalSupply();
    // vm.expectEmit(true, false, false, true);
    // emit SwappedStableTokenToBetToken(account1, amount);
    betStableSwap.depositStableTokenForBetToken(amount);
    uint256 betTokenSupplyAfter = betToken.totalSupply();
    vm.stopPrank();

    assertEq(betToken.balanceOf(account1), amount * betStableSwap.SWAP_RATIO());
    assertEq(stableToken.balanceOf(account1), 0);
    assertEq(
      betTokenSupplyAfter - betTokenSupplyBefore,
      amount * betStableSwap.SWAP_RATIO()
    );
  }

  function test_deposit0StableTokenForBetToken() public {
    vm.startPrank(account1);
    stableToken.approve(address(betStableSwap), 10**6);
    vm.expectRevert("BetStableSwap: Amount must be greater than 0");
    betStableSwap.depositStableTokenForBetToken(0);
    vm.stopPrank();

    assertEq(betToken.balanceOf(account1), 0);
    assertEq(stableToken.balanceOf(account1), 0);
  }

  function test_burnBetTokenForStableToken(uint256 amount) public {
    vm.assume(
      amount > 0 && amount <= type(uint256).max / betStableSwap.SWAP_RATIO()
    );
    _mintStableToken(account1, amount);
    vm.startPrank(account1);
    stableToken.approve(address(betStableSwap), amount);
    // vm.expectEmit(true, false, false, true);
    // emit SwappedStableTokenToBetToken(account1, amount);
    betStableSwap.depositStableTokenForBetToken(amount);

    betToken.approve(
      address(betStableSwap),
      amount * betStableSwap.SWAP_RATIO()
    );
    uint256 betTokenSupplyBefore = betToken.totalSupply();
    betStableSwap.burnBetTokenForStableToken(
      amount * betStableSwap.SWAP_RATIO()
    );
    uint256 betTokenSupplyAfter = betToken.totalSupply();
    vm.stopPrank();

    assertEq(betToken.balanceOf(account1), 0);
    assertEq(
      betTokenSupplyBefore - betTokenSupplyAfter,
      amount * betStableSwap.SWAP_RATIO()
    );
  }

  function test_burn0BetTokenForStableToken() public {
    vm.startPrank(account1);
    betToken.approve(address(betStableSwap), 10**6);
    vm.expectRevert("BetStableSwap: Amount must be greater than 0");
    betStableSwap.burnBetTokenForStableToken(0);
    vm.stopPrank();

    assertEq(betToken.balanceOf(account1), 0);
    assertEq(stableToken.balanceOf(account1), 0);
  }

  function _mintStableToken(address account, uint256 amount) internal {
    stableToken.mint(account, amount);
  }
}
