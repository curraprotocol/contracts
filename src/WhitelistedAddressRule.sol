// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Rule} from "./Rule.sol";

/// @author Dmytro Pintak <dmytro.pintak@gmail.com>
/// @title Rule contract, that allows to forward coins only to whitelisted address
contract WhitelistedAddressRule is Rule {
    address public immutable whitelisted;

    constructor(address _whitelisted) {
        whitelisted = _whitelisted;
    }

    /// @inheritdoc Rule
    function exec(uint256, address, uint256 value, address dest) external view override returns (address, uint256) {
        if (dest == address(0x0)) {
            return (whitelisted, value);
        }
        require(dest == whitelisted, "Dest");
        return (dest, value);
    }

    /// @inheritdoc Rule
    function execERC20(uint256, address, address, uint256 value, address dest)
        external
        view
        override
        returns (address, uint256)
    {
        if (dest == address(0x0)) {
            return (whitelisted, value);
        }
        require(dest == whitelisted, "Dest");
        return (dest, value);
    }

    /// @inheritdoc Rule
    function execERC721(uint256, address, address, uint256, address dest) external view override returns (address) {
        if (dest == address(0x0)) {
            return whitelisted;
        }
        require(dest == whitelisted, "Dest");
        return (dest);
    }

    /// @inheritdoc Rule
    function execERC1155(uint256, address, address, uint256, uint256 value, address dest)
        external
        view
        returns (address, uint256)
    {
        if (dest == address(0x0)) {
            return (whitelisted, value);
        }
        require(dest == whitelisted, "Dest");
        return (dest, value);
    }
}
