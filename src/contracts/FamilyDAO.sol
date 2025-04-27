// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FamilyNFT.sol";
import "./FamilyRegistry.sol";
import "forge-std/console.sol";


contract FamilyDAO {
    FamilyNFT public familyNFT;
    FamilyRegistry public registry;

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

    error NotNFTHolder();
    error AlreadyVoted();
    error VotingNotFinished();

    event ProposalCreated(uint256 id, address proposer, string description);
    event VoteCast(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id, bool passed);

    constructor(address nftAddress, FamilyRegistry _registry) {
        familyNFT = FamilyNFT(nftAddress);
        registry = _registry;
    }

    function createProposal(string memory description) external returns (uint256) {
        if (familyNFT.balanceOf(msg.sender) == 0) revert NotNFTHolder();

        uint256 proposalId = proposalCount++;
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.description = description;
        proposal.deadline = block.timestamp + 20;

        emit ProposalCreated(proposalId, msg.sender, description);
        return proposalId;
    }

    function vote(uint256 proposalId, bool support) external {
        if (familyNFT.balanceOf(msg.sender) == 0) revert NotNFTHolder();

        Proposal storage proposal = proposals[proposalId];
        if (proposal.hasVoted[msg.sender]) revert AlreadyVoted();

        proposal.hasVoted[msg.sender] = true;

        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }

        emit VoteCast(proposalId, msg.sender, support);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];

        if (block.timestamp < proposal.deadline) revert VotingNotFinished();
        require(!proposal.executed, "Proposal already executed");

        proposal.executed = true;

        bool passed = proposal.votesFor > proposal.votesAgainst;
        emit ProposalExecuted(proposalId, passed);

        if (passed) {
            bytes memory descriptionBytes = bytes(proposal.description);

            if (_startsWith(descriptionBytes, "ADD_MEMBER:")) {
                (address newMember, address parent, string memory role, string memory metadataURI) = _parseAddMember(descriptionBytes);

                // 🛠 Fix: Add ipfs:// prefix if missing
                bytes memory metadataBytes = bytes(metadataURI);
                if (metadataBytes.length >= 4) {
                    // Check if it already starts with ipfs://
                    bytes memory prefix = bytes("ipfs://");
                    bool hasPrefix = true;
                    for (uint i = 0; i < prefix.length; i++) {
                        if (i >= metadataBytes.length || metadataBytes[i] != prefix[i]) {
                            hasPrefix = false;
                            break;
                        }
                    }
                    if (!hasPrefix) {
                        metadataURI = string(abi.encodePacked("ipfs://", metadataURI));
                    }
                }

                registry.addFamilyMember(newMember, parent, role, metadataURI);
                familyNFT.mint(newMember, metadataURI);
            } 
            
            else if (_startsWith(descriptionBytes, "REMOVE_MEMBER:")) {
                address memberToRemove = _parseAddress(_slice(descriptionBytes, 14, descriptionBytes.length - 14));

                    uint256 balance = familyNFT.balanceOf(memberToRemove);
                    if (balance > 0) {
                        uint256 tokenId = _findTokenIdByOwner(memberToRemove);
                        familyNFT.burn(tokenId);
                    }

                    registry.removeFamilyMember(memberToRemove);
            }
        }

        delete proposals[proposalId];
    }

    function _startsWith(bytes memory description, string memory prefix) internal pure returns (bool) {
        bytes memory prefixBytes = bytes(prefix);
        if (description.length < prefixBytes.length) return false;
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (description[i] != prefixBytes[i]) return false;
        }
        return true;
    }

    function _parseAddMember(bytes memory description) internal pure returns (address newMember, address parent, string memory role, string memory metadataURI) {
        bytes memory delimiter = bytes(":");
        uint[4] memory positions;
        uint colonCount = 0;

        // Find the first 4 colons
        for (uint i = 0; i < description.length; i++) {
            if (description[i] == delimiter[0]) {
                if (colonCount < 4) {
                    positions[colonCount] = i;
                }
                colonCount++;
            }
        }

        require(colonCount >= 4, "Invalid add member format");

        newMember = _parseAddress(_slice(description, positions[0] + 1, positions[1] - positions[0] - 1));
        parent = _parseAddress(_slice(description, positions[1] + 1, positions[2] - positions[1] - 1));
        role = string(_slice(description, positions[2] + 1, positions[3] - positions[2] - 1));
        metadataURI = string(_slice(description, positions[3] + 1, description.length - positions[3] - 1));
    }


    function _split(bytes memory input, string memory delimiter) internal pure returns (string[] memory) {
        uint256 partsCount = 1;
        for (uint256 i = 0; i < input.length; i++) {
            if (input[i] == bytes(delimiter)[0]) {
                partsCount++;
            }
        }

        string[] memory parts = new string[](partsCount);
        uint256 partIndex = 0;
        uint256 start = 0;
        for (uint256 i = 0; i <= input.length; i++) {
            if (i == input.length || input[i] == bytes(delimiter)[0]) {
                bytes memory part = new bytes(i - start);
                for (uint256 j = 0; j < i - start; j++) {
                    part[j] = input[start + j];
                }
                parts[partIndex++] = string(part);
                start = i + 1;
            }
        }
        return parts;
    }

    function _slice(bytes memory input, uint256 start, uint256 length) internal pure returns (bytes memory) {
        bytes memory temp = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            temp[i] = input[start + i];
        }
        return temp;
    }

    function _parseAddress(bytes memory input) internal pure returns (address addr) {
        require(input.length == 42, "Invalid address length");
        bytes memory addrBytes = new bytes(20);
        for (uint256 i = 0; i < 20; i++) {
            addrBytes[i] = bytes1(_fromHexChar(uint8(input[2 + i * 2])) * 16 + _fromHexChar(uint8(input[3 + i * 2])));
        }
        assembly {
            addr := mload(add(addrBytes, 20))
        }
    }

    function _fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= "0" && bytes1(c) <= "9") {
            return c - uint8(bytes1("0"));
        }
        if (bytes1(c) >= "a" && bytes1(c) <= "f") {
            return 10 + c - uint8(bytes1("a"));
        }
        if (bytes1(c) >= "A" && bytes1(c) <= "F") {
            return 10 + c - uint8(bytes1("A"));
        }
        revert("Invalid hex character");
    }

    function _findTokenIdByOwner(address owner) internal view returns (uint256) {
        uint256 totalMinted = familyNFT.nextTokenId();
        for (uint256 tokenId = 0; tokenId < totalMinted; tokenId++) {
            if (familyNFT.ownerOf(tokenId) == owner) {
                return tokenId;
            }
        }
        revert("Token not found for owner");
    }

}

