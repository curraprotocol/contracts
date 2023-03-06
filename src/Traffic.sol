// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Counters} from "lib/openzeppelin-contracts/contracts/utils/Counters.sol";
import {Create2} from "lib/openzeppelin-contracts/contracts/utils/Create2.sol";
import {ERC721} from "lib/solmate/src/tokens/ERC721.sol";
import {LibClone} from "lib/solady/src/utils/LibClone.sol";

import {IForwarder} from "./IForwarder.sol";
import {Rule} from "./Rule.sol";
import {WhitelistedAddressRule} from "./WhitelistedAddressRule.sol";

/// @author Dmytro Pintak <dmytro.pintak@gmail.com>
/// @title Entry point contract to Curra protocol
contract Traffic is ERC721 {
    /// @dev used to generate NFT ids
    using Counters for Counters.Counter;

    /// @dev NFT ids counter
    Counters.Counter private ownershipIds;

    /// @notice Clones are used to create forwarder contracts, address of the implementation
    address public immutable forwarderImplementation;

    /// @notice OwnershipId => Rule contract address
    mapping(uint256 => address) private rules;

    event RuleSet(uint256 ownershipId, address value);

    modifier onlyTokenOwner(uint256 ownershipId) {
        require(ownerOf(ownershipId) == msg.sender, "Token owner");
        _;
    }

    constructor(address _forwarderImplementation) ERC721("Curra Forwarders Ownerships", "CFO") {
        forwarderImplementation = _forwarderImplementation;
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        return string(abi.encodePacked("https://api.curra.io/ownership/", id));
    }

    function _setRule(uint256 ownershipId, address value) internal {
        rules[ownershipId] = value;
        emit RuleSet(ownershipId, value);
    }

    function setRule(uint256 ownershipId, address value) public onlyTokenOwner(ownershipId) {
        _setRule(ownershipId, value);
    }

    function getRule(uint256 ownershipId) public view returns (address) {
        return rules[ownershipId];
    }

    /// @notice Used to mint new ownerships
    /// @notice If rule is not provided, then WhitelistedAddressRule will be used with msg.sender as a whitelisted address
    /// @param recipient - address to mint ownership to
    /// @param rule - address of the rule contract
    function mint(address recipient, address rule) public returns (uint256) {
        ownershipIds.increment();

        uint256 newItemId = ownershipIds.current();
        _mint(recipient, newItemId);

        address ruleToSet = rule;
        if (ruleToSet == address(0)) {
            ruleToSet = address(new WhitelistedAddressRule(recipient));
        }
        _setRule(newItemId, ruleToSet);

        return newItemId;
    }

    /// @notice Used to deploy new forwarder contract using CREATE2 clones
    function deployForwarder(uint256 ownershipId, bytes32 salt) internal returns (address instance) {
	address implementation = forwarderImplementation;

        assembly {
	    mstore(0x20, salt)
	    mstore(0x00, ownershipId)
	    let saltHash := keccak256(0x00, 0x40)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x21, 0x00)

            mstore(0x21, 0x5af43d3d93803e602a57fd5bf3)
            mstore(0x14, implementation)
            mstore(0x00, 0x602c3d8160093d39f33d3d3d3d363d3d37363d73)

            instance := create2(0, 0x0c, 0x35, saltHash)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x21, 0)
            // If `instance` is zero, revert.
            if iszero(instance) {
                // Store the function selector of `DeploymentFailed()`.
                mstore(0x00, 0x30116425)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Predicts forwarder address using CREATE2
    function computeForwarderAddress(uint256 ownershipId, bytes32 salt) public view returns (address) {
        return LibClone.predictDeterministicAddress(
            forwarderImplementation, keccak256(abi.encodePacked(ownershipId, salt)), address(this)
        );
    }

    // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ERC20 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    function flushERC20(uint256 ownershipId, bytes32 forwarderSalt, address token, uint256 value, address dest)
        public
    {
        address forwarderAddress = computeForwarderAddress(ownershipId, forwarderSalt);
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.execERC20(forwarderAddress, token, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushTokens(token, v, d);
    }

    function createForwarderERC20(
        uint256 ownershipId,
        bytes32 forwarderSalt,
        address token,
        uint256 value,
        address dest
    ) external {
        address forwarderAddress = deployForwarder(ownershipId, forwarderSalt);
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.execERC20(forwarderAddress, token, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushTokens(token, v, d);
    }
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑

    // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Coins ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    function flush(uint256 ownershipId, bytes32 forwarderSalt, uint256 value, address dest) public {
        address forwarderAddress = computeForwarderAddress(ownershipId, forwarderSalt);
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.exec(forwarderAddress, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flush(d, v);
    }

    function createForwarder(uint256 ownershipId, bytes32 forwarderSalt, uint256 value, address dest) external {
        address forwarderAddress = deployForwarder(ownershipId, forwarderSalt);
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.exec(forwarderAddress, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flush(d, v);
    }
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑

    // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ERC721 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    function flushERC721(uint256 ownershipId, uint256 id, bytes32 forwarderSalt, address token, address dest) public {
        address forwarderAddress = computeForwarderAddress(ownershipId, forwarderSalt);
        Rule rule = Rule(getRule(ownershipId));
        address d = rule.execERC721(forwarderAddress, token, id, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushERC721Token(token, id, d);
    }

    function createForwarderERC721(uint256 ownershipId, uint256 id, bytes32 forwarderSalt, address token, address dest)
        external
    {
        address forwarderAddress = deployForwarder(ownershipId, forwarderSalt);
        Rule rule = Rule(getRule(ownershipId));
        address d = rule.execERC721(forwarderAddress, token, id, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushERC721Token(token, id, d);
    }
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑

    // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ERC1155 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    function flushERC1155(
        uint256 ownershipId,
        uint256 id,
        bytes32 forwarderSalt,
        address token,
        uint256 value,
        address dest
    ) public {
        address forwarderAddress = computeForwarderAddress(ownershipId, forwarderSalt);
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.execERC1155(forwarderAddress, token, id, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushERC1155Tokens(token, id, v, d);
    }

    function createForwarderERC1155(
        uint256 ownershipId,
        uint256 id,
        bytes32 forwarderSalt,
        address token,
        uint256 value,
        address dest
    ) external {
        address forwarderAddress = deployForwarder(ownershipId, forwarderSalt);
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.execERC1155(forwarderAddress, token, id, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushERC1155Tokens(token, id, v, d);
    }
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑
}
