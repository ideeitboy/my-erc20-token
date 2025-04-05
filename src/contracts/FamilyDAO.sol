// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FamilyNFT.sol";

contract FamilyDAO {
    FamilyNFT public familyNFT;

    uint256 public proposalCount;

    struct Proposal {
        uint256 id;
        address proposer;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    mapping(uint256 => Proposal) public proposals;

    event ProposalCreated(uint256 id, address proposer, string description);
    event VoteCast(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id, bool passed);

    constructor(address nftAddress) {
        familyNFT = FamilyNFT(nftAddress);
    }

    modifier onlyVoter() {
        require(familyNFT.balanceOf(msg.sender) > 0, "Not an NFT holder");
        _;
    }

    function createProposal(string calldata description) external onlyVoter returns (uint256) {
        uint256 id = proposalCount++;

        Proposal storage p = proposals[id];
        p.id = id;
        p.proposer = msg.sender;
        p.description = description;
        p.deadline = block.timestamp + 3 days;

        emit ProposalCreated(id, msg.sender, description);
        return id;
    }

    function vote(uint256 proposalId, bool support) external onlyVoter {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp < p.deadline, "Voting closed");
        require(!p.hasVoted[msg.sender], "Already voted");

        p.hasVoted[msg.sender] = true;

        if (support) {
            p.votesFor += 1;
        } else {
            p.votesAgainst += 1;
        }

        emit VoteCast(proposalId, msg.sender, support);
    }

    /*
    executeProposal function here is replaced with the one below

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.deadline, "Voting not finished");
        require(!p.executed, "Already executed");

        p.executed = true;

        bool passed = p.votesFor > p.votesAgainst;

        emit ProposalExecuted(proposalId, passed);

        // In the future, you can act on this (like calling FamilyRegistry.addFamilyMember)
    }
    */

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(block.timestamp >= p.deadline, "Voting not finished");
        require(!p.executed, "Already executed");

        p.executed = true;
        bool passed = p.votesFor > p.votesAgainst;

        emit ProposalExecuted(proposalId, passed);

        if (passed) {
            // Parse: "ADD_MEMBER:0xNewMember:0xParent:role"
            if (_startsWith(p.description, "ADD_MEMBER:")) {
                string[] memory parts = _split(p.description, ":");

                address newAddr = parseAddr(parts[1]);
                address parentAddr = parseAddr(parts[2]);
                string memory role = parts[3];

                FamilyRegistry registry = FamilyRegistry(familyNFT.registry());
                registry.addFamilyMember(newAddr, parentAddr, role);
            }
        }
    }

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        return bytes(str).length >= bytes(prefix).length && keccak256(bytes(_substring(str, 0, bytes(prefix).length))) == keccak256(bytes(prefix));
    }

    function _substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for(uint i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function _split(string memory str, string memory delim) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        bytes memory delimBytes = bytes(delim);

        uint partsCount = 1;
        for (uint i = 0; i < strBytes.length - delimBytes.length + 1; i++) {
            bool matchDelim = true;
            for (uint j = 0; j < delimBytes.length; j++) {
                if (strBytes[i + j] != delimBytes[j]) {
                    matchDelim = false;
                    break;
                }
            }
            if (matchDelim) partsCount++;
        }

        string[] memory parts = new string[](partsCount);
        uint partIndex = 0;
        uint lastStart = 0;

        for (uint i = 0; i < strBytes.length - delimBytes.length + 1; i++) {
            bool matchDelim = true;
            for (uint j = 0; j < delimBytes.length; j++) {
                if (strBytes[i + j] != delimBytes[j]) {
                    matchDelim = false;
                    break;
                }
            }
            if (matchDelim) {
                parts[partIndex++] = _substring(str, lastStart, i);
                lastStart = i + delimBytes.length;
                i += delimBytes.length - 1;
            }
        }
        parts[partIndex] = _substring(str, lastStart, strBytes.length);
        return parts;
    }

    function parseAddr(string memory str) internal pure returns (address parsedAddress) {
        bytes memory tmp = bytes(str);
        uint160 iaddr = 0;
        uint160 b1;
        uint160 b2;
        for (uint i = 2; i < 2 + 2 * 20; i += 2) {
            iaddr *= 256;
            b1 = uint160(uint8(tmp[i]));
            b2 = uint160(uint8(tmp[i + 1]));
            b1 = b1 >= 97 ? b1 - 87 : (b1 >= 65 ? b1 - 55 : b1 - 48);
            b2 = b2 >= 97 ? b2 - 87 : (b2 >= 65 ? b2 - 55 : b2 - 48);
            iaddr += (b1 * 16 + b2);
        }
        return address(iaddr);
    }
}
