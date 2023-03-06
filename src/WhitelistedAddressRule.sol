// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Rule} from "./Rule.sol";

/// @author Dmytro Pintak <dmytro.pintak@gmail.com>
/// @title Rule contract, that allows to forward coins only to whitelisted address
contract WhitelistedAddressRule is Rule {
    address public immutable whitelisted;

    constructor(address _whitelisted) {
        whitelisted = _whitelisted;
    }

    /// @inheritdoc Rule
    function exec(address, uint256 value, address) external view override returns (address d, uint256 v) {
        d = whitelisted;
        v = value;
    }

    /// @inheritdoc Rule
    function execERC20(address, address, uint256 value, address)
        external
        view
        override
        returns (address d, uint256 v)
    {
        d = whitelisted;
        v = value;
    }

    /// @inheritdoc Rule
    function execERC721(address, address, uint256, address) external view override returns (address d) {
        d = whitelisted;
    }

    /// @inheritdoc Rule
    function execERC1155(address, address, uint256, uint256 value, address)
        external
        view
        returns (address d, uint256 v)
    {
        d = whitelisted;
        v = value;
    }
}
