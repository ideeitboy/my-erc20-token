// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FamilyNFT.sol";
import "./FamilyRegistry.sol";

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

    event ProposalCreated(uint256 id, address proposer, string description);
    event VoteCast(uint256 proposalId, address voter, bool support);
    event ProposalExecuted(uint256 id, bool passed);

    constructor(address nftAddress, FamilyRegistry _registry) {
        familyNFT = FamilyNFT(nftAddress);
        registry = _registry;
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

    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];

        require(block.timestamp >= p.deadline, "Voting not finished");
        require(!p.executed, "Proposal already executed");

        p.executed = true;

        bool passed = p.votesFor > p.votesAgainst;

        emit ProposalExecuted(proposalId, passed);

        if (!passed) {
            return;
        }

        if (_startsWith(p.description, "ADD_MEMBER:")) {
            (address newMember, address parent, string memory role) = _parseAddMember(p.description);
            registry.addFamilyMember(newMember, parent, role);
        } else if (_startsWith(p.description, "REMOVE_MEMBER:")) {
            address memberToRemove = _parseRemoveMember(p.description);
            registry.removeFamilyMember(memberToRemove);
        }
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCount;
    }

    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);

        if (prefixBytes.length > strBytes.length) {
            return false;
        }

        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) {
                return false;
            }
        }

        return true;
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

    function _indexOf(bytes memory str, string memory delim, uint start) internal pure returns (uint) {
        bytes memory delimBytes = bytes(delim);

        for (uint i = start; i < str.length - delimBytes.length + 1; i++) {
            bool matchFound = true;

            for (uint j = 0; j < delimBytes.length; j++) {
                if (str[i + j] != delimBytes[j]) {
                    matchFound = false;
                    break;
                }
            }

            if (matchFound) {
                return i;
            }
        }

        revert("Delimiter not found");
    }

    function _hexStringToUint(bytes memory hexString) internal pure returns (uint result) {
        for (uint i = 0; i < hexString.length; i++) {
            uint digit = uint(uint8(hexString[i]));

            if (digit >= 48 && digit <= 57) {
                result = result * 16 + (digit - 48);
            } else if (digit >= 97 && digit <= 102) {
                result = result * 16 + (digit - 87);
            } else if (digit >= 65 && digit <= 70) {
                result = result * 16 + (digit - 55);
            } else {
                revert("Invalid hex character");
            }
        }
    }

    function _parseAddMember(string memory desc) internal pure returns (address, address, string memory) {
        bytes memory strBytes = bytes(desc);
        uint8 partsCount = 0;
        bytes[] memory parts = new bytes[](4);

        uint256 start = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == ":") {
                parts[partsCount++] = _slice(strBytes, start, i);
                start = i + 1;
            }
        }
        parts[partsCount++] = _slice(strBytes, start, strBytes.length);

        require(partsCount == 4, "Invalid ADD_MEMBER format");

        address newMember = _parseAddress(parts[1]);
        address parent = _parseAddress(parts[2]);
        string memory role = string(parts[3]);

        return (newMember, parent, role);
    }

    function _slice(bytes memory data, uint256 start, uint256 end) internal pure returns (bytes memory) {
        require(end > start, "Invalid slice bounds");
        bytes memory result = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = data[i];
        }
        return result;
    }

    function _parseAddress(bytes memory input) internal pure returns (address addr) {
        require(input.length == 42, "Invalid address length");

        uint160 result = 0;
        for (uint256 i = 2; i < 42; i++) {
            result <<= 4;
            uint8 b = uint8(input[i]);

            if (b >= 48 && b <= 57) result |= uint160(b - 48);
            else if (b >= 65 && b <= 70) result |= uint160(b - 55);
            else if (b >= 97 && b <= 102) result |= uint160(b - 87);
            else revert("Invalid address character");
        }
        return address(result);
    }

    function _parseRemoveMember(string memory desc) internal pure returns (address) {
        bytes memory descBytes = bytes(desc);

        uint256 colonIndex = _indexOf(descBytes, ":", 0);
        require(colonIndex != type(uint256).max, "Invalid format");

        bytes memory addrBytes = _slice(descBytes, colonIndex + 1, descBytes.length);
        return _parseAddress(addrBytes);
    }
}
