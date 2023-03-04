// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.17 <0.9.0;


import "lib/forge-std/src/Script.sol";
import {ERC20PresetFixedSupply} from "lib/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import "../src/Forwarder.sol";
import "../src/Traffic.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        address trafficAddress = computeCreateAddress(msg.sender, vm.getNonce(msg.sender) + 1);
        Forwarder forwarder = new Forwarder(trafficAddress);
        new Traffic(address(forwarder));

        vm.stopBroadcast();
    }
}
