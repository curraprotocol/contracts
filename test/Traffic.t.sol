// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.17 <0.9.0;

import "forge-std/Test.sol";

import "lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

import "../src/Forwarder.sol";
import "../src/Traffic.sol";

contract TrafficTest is Test {
    Traffic traffic;
    Forwarder forwarder;
    ERC20 erc20;

    address public constant DEPLOYER = 0x2172530Fb58886b3466427BD60236E63FF8e4BE5;
    address public constant USER = 0x94750381bE1AbA0504C666ee1DB118F68f0780D4;

    bytes20 constant salt = "5";
    uint256 constant ownershipId = 1;
    uint256 constant toFlush = 420;
    uint256 constant tokenIdToFlush = 420;
    address immutable forwarderAddress;

    constructor() {
        vm.startPrank(DEPLOYER);

        address trafficAddress = computeCreateAddress(DEPLOYER, 1);
        forwarder = new Forwarder(trafficAddress);
        traffic = new Traffic(
            address(forwarder)
        );
        forwarderAddress = traffic.computeForwarderAddress(ownershipId, salt);

        erc20 = new ERC20("", "");

        vm.stopPrank();
    }

    // ERC20
    function testCreateForwarderERC20() public {
        vm.startPrank(USER);

        traffic.mint(USER, address(0));

        vm.stopPrank();

        // simulate user transfer to deposit address
        deal({token: address(erc20), to: forwarderAddress, give: toFlush});

        traffic.createForwarderERC20(ownershipId, salt, address(erc20), toFlush, USER);

        require(erc20.balanceOf(forwarderAddress) == 0, "Forwarder shouldn't have tokens");
        require(erc20.balanceOf(USER) == toFlush, "User should have tokens");
    }

    function testFlushERC20() public {
        // create and flush for first time
        testCreateForwarderERC20();

        // simulate user transfer to deposit address
        deal({token: address(erc20), to: forwarderAddress, give: toFlush});

        traffic.flushERC20(ownershipId, salt, address(erc20), toFlush, USER);

        require(erc20.balanceOf(forwarderAddress) == 0, "Forwarder shouldn't have tokens");
        require(erc20.balanceOf(USER) == toFlush * 2, "User should have tokens");
    }

    // Coins
    function testCreateForwarder() public {
        vm.startPrank(USER);

        traffic.mint(USER, address(0));

        vm.stopPrank();

        // simulate user transfer to deposit address
        deal({to: forwarderAddress, give: toFlush});

        traffic.createForwarder(ownershipId, salt, toFlush, USER);

        require(forwarderAddress.balance == 0, "Forwarder shouldn't have tokens");
        require(USER.balance == toFlush, "User should have tokens");
    }

    function testFlush() public {
        // create and flush for first time
        testCreateForwarder();

        // simulate user transfer to deposit address
        deal({to: forwarderAddress, give: toFlush});

        traffic.flush(ownershipId, salt, toFlush, USER);

        require((forwarderAddress).balance == 0, "Forwarder shouldn't have tokens");
        require((USER).balance == toFlush * 2, "User should have tokens");
    }
}
