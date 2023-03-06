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
    function deployForwarder(uint256 ownershipId, bytes32 salt) internal returns (address) {
        // include the signers in the salt so any contract deployed to a given address must have the same signers
        bytes32 finalSalt = keccak256(abi.encodePacked(ownershipId, salt));
        return LibClone.cloneDeterministic(forwarderImplementation, finalSalt);
    }

    /// @notice Predicts forwarder address using CREATE2
    function computeForwarderAddress(uint256 ownershipId, bytes32 salt) public view returns (address) {
        return LibClone.predictDeterministicAddress(
            forwarderImplementation, keccak256(abi.encodePacked(ownershipId, salt)), address(this)
        );
    }

    // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ERC20 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    function _flushERC20(uint256 ownershipId, address forwarderAddress, address token, uint256 value, address dest)
        internal
    {
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.execERC20(forwarderAddress, token, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushTokens(token, v, d);
    }

    function flushERC20(uint256 ownershipId, bytes32 forwarderSalt, address token, uint256 value, address dest)
        public
    {
        address forwarder = computeForwarderAddress(ownershipId, forwarderSalt);
        _flushERC20(ownershipId, forwarder, token, value, dest);
    }

    function createForwarderERC20(
        uint256 ownershipId,
        bytes32 forwarderSalt,
        address token,
        uint256 value,
        address dest
    ) external {
        address forwarder = deployForwarder(ownershipId, forwarderSalt);
        _flushERC20(ownershipId, forwarder, token, value, dest);
    }
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑

    // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ Coins ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    function _flush(uint256 ownershipId, address forwarderAddress, uint256 value, address dest) internal {
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.exec(forwarderAddress, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flush(d, v);
    }

    function flush(uint256 ownershipId, bytes32 forwarderSalt, uint256 value, address dest) public {
        address forwarder = computeForwarderAddress(ownershipId, forwarderSalt);
        _flush(ownershipId, forwarder, value, dest);
    }

    function createForwarder(uint256 ownershipId, bytes32 forwarderSalt, uint256 value, address dest) external {
        address forwarder = deployForwarder(ownershipId, forwarderSalt);
        _flush(ownershipId, forwarder, value, dest);
    }
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑
    // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ERC721 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    function execRuleERC721(uint256 ownershipId, address forwarder, address token, uint256 id, address dest)
        internal
        view
        returns (address)
    {
        Rule rule = Rule(getRule(ownershipId));
        return rule.execERC721(forwarder, token, id, dest);
    }

    function _flushERC721(uint256 ownershipId, uint256 id, address forwarderAddress, address token, address dest)
        internal
    {
        (address d) = execRuleERC721(ownershipId, forwarderAddress, token, id, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushERC721Token(token, id, d);
    }

    function flushERC721(uint256 ownershipId, uint256 id, bytes32 forwarderSalt, address token, address dest) public {
        address forwarderAddress = computeForwarderAddress(ownershipId, forwarderSalt);
        _flushERC721(ownershipId, id, forwarderAddress, token, dest);
    }

    function createForwarderERC721(
        uint256 ownershipId,
        uint256 id,
        bytes32 forwarderSalt,
        address tokenContractAddress,
        address dest
    ) external {
        address forwarder = deployForwarder(ownershipId, forwarderSalt);
        _flushERC721(ownershipId, id, forwarder, tokenContractAddress, dest);
    }
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑

    // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ERC1155 ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
    function _flushERC1155(
        uint256 ownershipId,
        uint256 id,
        address forwarderAddress,
        address token,
        uint256 value,
        address dest
    ) internal {
        Rule rule = Rule(getRule(ownershipId));
        (address d, uint256 v) = rule.execERC1155(forwarderAddress, token, id, value, dest);
        IForwarder forwarder = IForwarder(forwarderAddress);
        forwarder.flushERC1155Tokens(token, id, v, d);
    }

    function flushERC1155(
        uint256 ownershipId,
        uint256 id,
        bytes32 forwarderSalt,
        address token,
        uint256 value,
        address dest
    ) public {
        address forwarderAddress = computeForwarderAddress(ownershipId, forwarderSalt);
        _flushERC1155(ownershipId, id, forwarderAddress, token, value, dest);
    }

    function createForwarderERC1155(
        uint256 ownershipId,
        uint256 id,
        bytes32 forwarderSalt,
        address token,
        uint256 value,
        address dest
    ) external {
        address forwarder = deployForwarder(ownershipId, forwarderSalt);
        _flushERC1155(ownershipId, id, forwarder, token, value, dest);
    }
    // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑
}
