// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.17 <0.9.0;

import "lib/forge-std/src/Script.sol";

import "../src/TestToken.sol";

contract DeployTestToken is Script {
    function run() external {
        vm.startBroadcast();

        new TestToken();

        vm.stopBroadcast();
    }
}
