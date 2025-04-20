// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
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
        dao = new FamilyDAO(address(nft), registry);

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

        vm.startPrank(admin);

        string memory desc = string.concat(
            "ADD_MEMBER:",
            vm.toString(cousin),
            ":",
            vm.toString(admin),
            ":cousin"
        );

        uint proposalId = dao.createProposal(desc);

        vm.stopPrank();

        vm.prank(daughter);
        dao.vote(proposalId, true);

        vm.prank(son);
        dao.vote(proposalId, true);

        vm.warp(block.timestamp + 3 days);

        vm.prank(admin);
        dao.executeProposal(proposalId);

        (bool exists,, address parent) = registry.members(cousin);
        assertTrue(exists, "Cousin should be registered");
        assertEq(parent, admin);
    }

    function testExecuteRemoveMemberProposal() public {
        address cousin = address(5);

        // Step 1: Add cousin manually (simulate a pre-existing member)
        vm.prank(admin);
        registry.setFakeMember(cousin, true, "cousin", admin);

        // debug: check initial state
        (bool existsBefore,,) = registry.members(cousin);
        console.log("Before proposal execution: cousin exists =", existsBefore);
        
        // Step 2: Create REMOVE_MEMBER proposal
        string memory desc = string.concat("REMOVE_MEMBER:", vm.toString(cousin));
        vm.prank(admin);
        uint id = dao.createProposal(desc);

        // Step 3: Vote FOR with daughter and son
        vm.prank(daughter);
        dao.vote(id, true);

        vm.prank(son);
        dao.vote(id, true);

        // Step 4: Fast forward time to pass the voting deadline
        vm.warp(block.timestamp + 3 days + 1);

        // Step 5: Execute the proposal
        vm.prank(admin);
        dao.executeProposal(id);

        // Check post-state
        (bool existsAfter,,) = registry.members(cousin);
        console.log("After proposal execution: cousin exists =", existsAfter);


        // Step 6: Verify cousin was removed
        (bool exists,,) = registry.members(cousin);
        assertFalse(exists, "Cousin should be removed");
    }




}
