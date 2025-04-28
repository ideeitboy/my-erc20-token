// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "../../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./FamilyRegistry.sol";

contract FamilyNFT is ERC721URIStorage, Ownable(msg.sender) {
    uint256 public nextTokenId;
    mapping(address => bool) public hasMinted;
    mapping(uint256 => string) public tokenMetadataURI;

    FamilyRegistry public registry;
    address public familyDAO;

    constructor(string memory name, string memory symbol, address registryAddress)
        ERC721(name, symbol)
    {
        registry = FamilyRegistry(registryAddress);
    }

    function getMetadataURI(uint256 tokenId) external view returns (string memory) {
        return tokenMetadataURI[tokenId];
    }

    function mint(address to, string memory _tokenURI) external {
        require(
            registry.isFamilyMember(to) || msg.sender == familyDAO,
            "Not a registered family member"
        );

        require(!hasMinted[to], "This address has already minted");

        address parent = registry.getParent(to);
        if (parent != address(0)) {
            require(balanceOf(parent) > 0, "Parent has not minted an NFT yet");
        }

        _safeMint(to, nextTokenId);
        _setTokenURI(nextTokenId, _tokenURI);
        tokenMetadataURI[nextTokenId] = _tokenURI;
        hasMinted[to] = true;
        nextTokenId++;
    }

    function setFamilyDAO(address dao) external onlyOwner {
        require(familyDAO == address(0), "DAO already set");
        familyDAO = dao;
    }

    

    function adminMint(string memory cid) external onlyOwner{
        require(!hasMinted[msg.sender], "Already minted");
        _safeMint(msg.sender, nextTokenId);
        //cid = "bafkreif4oe2fjraicflpxkjgi3j32gvxvzcq4qogxw6kuxrero3egrgmfi";
    
        string memory ipfsURI = string.concat("ipfs://", cid);

        _setTokenURI(nextTokenId, ipfsURI);
        tokenMetadataURI[nextTokenId] = ipfsURI;
        hasMinted[msg.sender] = true;
        nextTokenId++;
    }

    function burn(uint256 tokenId) external {
        require(msg.sender == familyDAO, "Only DAO can burn");
        address owner = ownerOf(tokenId);
        _burn(tokenId);
        hasMinted[owner] = false;
    }



}
