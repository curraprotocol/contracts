// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.17 <0.9.0;

import "lib/forge-std/src/Script.sol";

import "../src/TestToken.sol";

contract Playground is Script {
    function run() external {
        vm.startBroadcast();

        TestToken t = TestToken(0xA5D387f804c88bd326B5B9888aE4018A5ba1D760);
        t.mint(0xcdCffa6f5dEB2B947BabEE378654a46ea5d05892, 10000000000000000000);

        vm.stopBroadcast();
    }
}
