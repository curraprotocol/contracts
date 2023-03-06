// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.17 <0.9.0;

import "lib/forge-std/src/Script.sol";
import {ERC20PresetFixedSupply} from
    "lib/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

import "../src/Forwarder.sol";
import "../src/Traffic.sol";

contract DeployWithDemoTxs is Script {
    function run() external {
        vm.startBroadcast();

        address trafficAddress = computeCreateAddress(msg.sender, vm.getNonce(msg.sender) + 1);
        Forwarder forwarder = new Forwarder(trafficAddress);
        Traffic traffic = new Traffic(address(forwarder) );

        ERC20PresetFixedSupply erc20 = new ERC20PresetFixedSupply("TestCUR", "TestCUR", 10000000, msg.sender);

        traffic.mint(msg.sender, address(0));

        uint256 tokenId = 1;

        address forwarderAddress = traffic.computeForwarderAddress(tokenId, hex"00");

        uint256 tokensToFlush = 10000000;
        // mint tokens
        erc20.transfer(forwarderAddress, tokensToFlush);
        traffic.createForwarderERC20(tokenId, hex"00", address(erc20), tokensToFlush, msg.sender);
        vm.stopBroadcast();
    }
}
