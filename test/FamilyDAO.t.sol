// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/contracts/FamilyNFT.sol";
import "../src/contracts/FamilyRegistry.sol";
import "../src/contracts/FamilyDAO.sol";


// TEST COMMENT


contract FamilyDAOTest is Test {
    FamilyRegistry public registry;
    FamilyNFT public nft;
    FamilyDAO public dao;

    address admin = address(1);
    address daughter = address(2);
    address son = address(3);
    address stranger = address(4);


    function setUp() public {
        admin = address(1);
        daughter = address(2);
        son = address(3);

        vm.startPrank(admin);

        // Deploy registry and DAO
        registry = new FamilyRegistry();
        nft = new FamilyNFT("FamilyNFT", "FNFT", address(registry));
        dao = new FamilyDAO(address(nft));

        // Set DAO as the only authorized caller on registry
        registry.setDAO(address(dao));

        // Admin is a registered family member (fake for now)
        registry.setFakeMember(admin, true, "admin", address(0));
        registry.setFakeMember(daughter, true, "daughter", admin);
        registry.setFakeMember(son, true, "son", admin);

        // Mint an NFT to admin so they can propose/vote
        nft.mint(admin, "ipfs://admin-nft");
        nft.mint(daughter, "ipfs://daughter-nft");
        nft.mint(son, "ipfs://son-nft");


        // Use DAO to add daughter & son via proposal execution
        // We'll simulate proposals directly in tests instead of doing it here

        vm.stopPrank();
    }


    function testCreateProposal() public {
        vm.prank(daughter);
        uint256 proposalId = dao.createProposal("Add new cousin to the family");
        assertEq(proposalId, 0);
    }

    function testVoteOnProposal() public {
        vm.prank(daughter);
        uint256 proposalId = dao.createProposal("Add new cousin");

        vm.prank(son);
        dao.vote(proposalId, true);

        // Should revert if voting again
        vm.expectRevert("Already voted");
        vm.prank(son);
        dao.vote(proposalId, true);
    }

    function testOnlyNFTCanVoteOrPropose() public {
        // Should fail for stranger
        vm.expectRevert("Not an NFT holder");
        vm.prank(stranger);
        dao.createProposal("Stranger shouldn't be here");

        vm.prank(daughter);
        uint256 id = dao.createProposal("Add new aunt");

        vm.expectRevert("Not an NFT holder");
        vm.prank(stranger);
        dao.vote(id, true);
    }

    function testExecuteProposalPasses() public {
        vm.prank(admin);
        uint256 proposalId = dao.createProposal("Invite Grandma");

        vm.prank(daughter);
        dao.vote(proposalId, true);

        vm.prank(son);
        dao.vote(proposalId, false);

        // Fast-forward 3 days
        vm.warp(block.timestamp + 3 days + 1);

        vm.prank(admin);
        dao.executeProposal(proposalId);
    }

    function testExecuteFailsBeforeDeadline() public {
        vm.prank(admin);
        uint256 proposalId = dao.createProposal("Add Uncle Bob");

        vm.prank(daughter);
        dao.vote(proposalId, true);

        vm.expectRevert("Voting not finished");
        vm.prank(admin);
        dao.executeProposal(proposalId);
    }

    function testExecuteAddMemberProposal() public {
        address cousin = address(5);

        // Create proposal
        vm.prank(admin);
        uint256 proposalId = dao.createProposal("ADD_MEMBER:0x0000000000000000000000000000000000000005:0x0000000000000000000000000000000000000001:cousin");

        // Vote FOR the proposal
        vm.prank(daughter);
        dao.vote(proposalId, true);

        vm.prank(son);
        dao.vote(proposalId, true);

        // Fast-forward time past deadline
        vm.warp(block.timestamp + 3 days + 1);

        // Execute
        vm.prank(admin);
        dao.executeProposal(proposalId);

        // Check: cousin should be registered
        FamilyRegistry reg = FamilyRegistry(address(registry));
        (bool exists, string memory role, ) = reg.members(cousin);

        assertTrue(exists, "Cousin should be registered");
        assertEq(role, "cousin");
    }

}
