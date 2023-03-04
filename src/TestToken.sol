// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor() ERC20("TestCUR", "TestCUR") {}

    function mint(address _to, uint256 value) external {
        super._mint(_to, value);
    }
}
