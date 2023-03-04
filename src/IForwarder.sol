// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/// @author Dmytro Pintak <dmytro.pintak@gmail.com>
/// @title Rule interface, can be implemented by any contract to be used as a rule in Traffic.sol contract
interface IForwarder {
    /// @notice Execute a coins transfer from the forwarder to the dest address
    function flush(address dest, uint256 value) external;

    /// @notice Execute a ERC20 transfer from the forwarder to the dest address
    function flushTokens(address token, uint256 value, address dest) external;

    /// @notice Execute a ERC721 transfer from the forwarder to the dest address
    function flushERC721Token(address token, uint256 id, address dest) external;

    /// @notice Execute a ERC1155 transfer from the forwarder to the dest address
    function flushERC1155Tokens(address token, uint256 id, uint256 value, address dest) external;
}
