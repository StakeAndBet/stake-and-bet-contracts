// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";

contract ConsumerContractScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
    }
}
