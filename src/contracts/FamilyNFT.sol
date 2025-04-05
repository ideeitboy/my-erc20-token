// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./FamilyRegistry.sol";


contract FamilyNFT is ERC721URIStorage, Ownable(msg.sender) {
    uint256 public nextTokenId;
    mapping(address => bool) public hasMinted;
    //address public registry; // Contract address of the FamilyRegistry
    FamilyRegistry public registry;

    //constructor(string memory name, string memory symbol, address registryAddress) 
    constructor(string memory name, string memory symbol, address registryAddress) 
    
    
    ERC721(name, symbol){
        registry = FamilyRegistry(registryAddress);
    }


    modifier onlyFamilyMember() 
    {
        require(FamilyRegistry(registry).isFamilyMember(msg.sender), "Not a registered family member");
        _;
    }

    function mint(address to, string memory tokenURI) external onlyFamilyMember {
        require(!hasMinted[to], "This address has already minted");

        address parent = FamilyRegistry(registry).getParent(to);

        if (parent != address(0)) {
            require(balanceOf(parent) > 0, "Parent has not minted an NFT yet");
        }
        
        // require(parent != address(0), "No parent registered");
        // require(balanceOf(parent) > 0, "Parent has not minted an NFT yet");

        _safeMint(to, nextTokenId);
        _setTokenURI(nextTokenId, tokenURI);
        hasMinted[to] = true;
        nextTokenId++;
    }

}

// interface FamilyRegistry {
//    function isFamilyMember(address user) external view returns (bool);
// }
