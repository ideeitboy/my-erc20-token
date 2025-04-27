// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/contracts/FamilyNFT.sol";
import "../src/contracts/FamilyRegistry.sol";
import "forge-std/console.sol";

contract FamilyNFTRegistryTest is Test {
    FamilyNFT public nft;
    FamilyRegistry public registry;

    address admin = address(1);
    address daughter = address(2);
    address son = address(3);

    function setUp() public {
        vm.startPrank(admin);

        // Deploy registry and NFT
        registry = new FamilyRegistry();
        nft = new FamilyNFT("FamilyNFT", "FNFT", address(registry));

        // Link DAO or NFT as the authorized caller
        registry.setDAO(address(nft));

        // Register fake family members (so they can mint)
        registry.setFakeMember(admin, true, "admin", address(0));
        registry.setFakeMember(daughter, true, "daughter", admin);
        registry.setFakeMember(son, true, "son", admin);

        vm.stopPrank();
    }

    function testRegistryConnection() public view {
        // Ensure NFT contract knows the correct registry address

        assertEq(address(nft.registry()), address(registry));
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

    function testMintByStrangerFails() public {
        address stranger = address(4);

        vm.expectRevert("Not a registered family member");

        vm.prank(stranger);
        nft.mint(stranger, "ipfs://should-fail");
    }

    function testChildCanOnlyMintIfParentHasNFT() public {
        // Parent mints first
        vm.prank(admin);
        nft.mint(admin, "ipfs://admin-nft");

        // Now daughter can mint
        vm.prank(daughter);
        nft.mint(daughter, "ipfs://daughter-nft");

        assertEq(nft.ownerOf(1), daughter);
    }

    function testMintFailsIfParentHasNotMinted() public {
        // Daughter tries to mint without parent minting
        vm.expectRevert("Parent has not minted an NFT yet");
        vm.prank(daughter);
        nft.mint(daughter, "ipfs://fail");
    }
}
