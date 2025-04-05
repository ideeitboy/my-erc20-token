// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/contracts/FamilyNFT.sol";
import "../src/contracts/FamilyRegistry.sol";

contract FamilyNFTRegistryTest is Test 
{
    FamilyNFT public nft;
    FamilyRegistry public registry;

    address admin = address(1);
    address daughter = address(2);

    function setUp() public 
    {
        // Pretend to be the admin deploying the registry
        vm.prank(admin);
        registry = new FamilyRegistry();

        // Add daughter to the registry
        vm.prank(admin);
        registry.addFamilyMember(daughter, admin, "daughter");

        // Deploy NFT contract using the registry's address
        vm.prank(admin);
        nft = new FamilyNFT("Family", "FAM", address(registry));
    }

    function testRegistryConnection() public view 
    {
        // Ensure NFT contract knows the correct registry address
        assertEq(nft.registry(), address(registry));
    }

    function testMintByFamilyMember() public {
        // Parent must mint first
        vm.prank(admin);
        nft.mint(admin, "ipfs://admin-nft");

        // Now daughter can mint
        vm.prank(daughter);
        nft.mint(daughter, "ipfs://my-daughter-nft");

        assertEq(nft.ownerOf(1), daughter);
        assertEq(nft.tokenURI(1), "ipfs://my-daughter-nft");
    }


    function testMintByStrangerFails() public 
    {
        address stranger = address(3);

        vm.expectRevert("Not a registered family member");

        vm.prank(stranger);
        nft.mint(stranger, "ipfs://should-fail");
    }

    function testChildCanOnlyMintIfParentHasNFT() public 
    {
    // Parent mints first
    vm.prank(admin);
    nft.mint(admin, "ipfs://admin-nft");

    // Now daughter can mint
    vm.prank(daughter);
    nft.mint(daughter, "ipfs://daughter-nft");

    assertEq(nft.ownerOf(1), daughter);
    }


    function test_RevertWhen_ParentHasNotMinted() public 
    {
        // Daughter tries to mint without parent minting
        vm.expectRevert("Parent has not minted an NFT yet");
        vm.prank(daughter);
        nft.mint(daughter, "ipfs://fail");
    }   


}
