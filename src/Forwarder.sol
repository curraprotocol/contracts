// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "lib/solmate/src/utils/SafeTransferLib.sol" as Mate;
import {IERC1155} from "lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";

import {IForwarder} from "./IForwarder.sol";

contract Forwarder is IForwarder {
    /// @notice Address of the invoker, essentially the Curra entry point contract Traffic.sol
    address public immutable invoker;

    constructor(address _invoker) {
        invoker = _invoker;
    }

    /// @notice Modifier to check if the caller is the invoker,
    modifier onlyInvoker() {
        require(msg.sender == invoker);
        _;
    }

    fallback() external payable {}

    receive() external payable {}

    /// @inheritdoc IForwarder
    function flush(address dest, uint256 value) public override onlyInvoker {
        Mate.SafeTransferLib.safeTransferETH(dest, value);
    }

    /// @inheritdoc IForwarder
    function flushTokens(address tokenContractAddress, uint256 value, address dest)
        external
        virtual
        override
        onlyInvoker
    {
        Mate.SafeTransferLib.safeTransfer(Mate.ERC20(tokenContractAddress), dest, value);
    }

    /// @inheritdoc IForwarder
    function flushERC721Token(address tokenContractAddress, uint256 id, address dest)
        external
        virtual
        override
        onlyInvoker
    {
        IERC721 instance = IERC721(tokenContractAddress);
        instance.safeTransferFrom(address(this), dest, id);
    }

    /// @inheritdoc IForwarder
    function flushERC1155Tokens(address tokenContractAddress, uint256 id, uint256 value, address dest)
        external
        virtual
        override
        onlyInvoker
    {
        IERC1155 instance = IERC1155(tokenContractAddress);
        instance.safeTransferFrom(address(this), dest, id, value, "");
    }
}
