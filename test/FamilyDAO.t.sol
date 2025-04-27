// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "../lib/forge-std/src/Test.sol";
import "../lib/forge-std/src/console.sol";
import "../src/contracts/FamilyNFT.sol";
import "../src/contracts/FamilyRegistry.sol";
import "../src/contracts/FamilyDAO.sol";

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

        registry = new FamilyRegistry();
        nft = new FamilyNFT("FamilyNFT", "FNFT", address(registry));
        dao = new FamilyDAO(address(nft), registry);

        registry.setDAO(address(dao));

        registry.setFakeMember(admin, true, "admin", address(0));
        registry.setFakeMember(daughter, true, "daughter", admin);
        registry.setFakeMember(son, true, "son", admin);

        nft.mint(admin, "https://pink-labour-ox-753.mypinata.cloud/ipfs/bafkreichiugv37vbqdrbhlizcpldcfiquwkfpjxslbqrv2jzxjyai2dzia?pinataGatewayToken=m-OsOwJyM0daP06Gyqh9UDfa9__UgsIT22Z0br4IZ2h-LrIvY5w5H3FWN8E15G3J");

        string memory uri = nft.tokenURI(0);
        emit log_string(uri);
        assertEq(uri, "https://pink-labour-ox-753.mypinata.cloud/ipfs/bafkreichiugv37vbqdrbhlizcpldcfiquwkfpjxslbqrv2jzxjyai2dzia?pinataGatewayToken=m-OsOwJyM0daP06Gyqh9UDfa9__UgsIT22Z0br4IZ2h-LrIvY5w5H3FWN8E15G3J");

        nft.mint(daughter, "ipfs://daughter-nft");
        nft.mint(son, "ipfs://son-nft");

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

        vm.expectRevert(FamilyDAO.AlreadyVoted.selector);
        vm.prank(son);
        dao.vote(proposalId, true);
    }

    function testOnlyNFTCanVoteOrPropose() public {
        vm.expectRevert(FamilyDAO.NotNFTHolder.selector);
        vm.prank(stranger);
        dao.createProposal("Stranger shouldn't be here");

        vm.prank(daughter);
        uint256 id = dao.createProposal("Add new aunt");

        vm.expectRevert(FamilyDAO.NotNFTHolder.selector);
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

        vm.warp(block.timestamp + 3 days + 1);

        vm.prank(admin);
        dao.executeProposal(proposalId);
    }

    function testExecuteFailsBeforeDeadline() public {
        vm.prank(admin);
        uint256 proposalId = dao.createProposal("Add Uncle Bob");

        vm.prank(daughter);
        dao.vote(proposalId, true);

        vm.expectRevert(FamilyDAO.VotingNotFinished.selector);
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
            ":cousin:",
            "ipfs://dummy-uri"
        );
        string memory desc = string.concat("ADD_MEMBER:", vm.toString(cousin), ":", vm.toString(admin), ":cousin:", "ipfs://dummy-uri");

        uint256 proposalId = dao.createProposal(desc);

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

        vm.prank(admin);
        registry.setFakeMember(cousin, true, "cousin", admin);

        (bool existsBefore,,) = registry.members(cousin);
        console.log("Before proposal execution: cousin exists =", existsBefore);

        string memory desc = string.concat("REMOVE_MEMBER:", vm.toString(cousin));
        vm.prank(admin);
        uint256 id = dao.createProposal(desc);

        vm.prank(daughter);
        dao.vote(id, true);

        vm.prank(son);
        dao.vote(id, true);

        vm.warp(block.timestamp + 3 days + 1);

        vm.prank(admin);
        dao.executeProposal(id);

        (bool existsAfter,,) = registry.members(cousin);
        console.log("After proposal execution: cousin exists =", existsAfter);

        (bool exists,,) = registry.members(cousin);
        assertFalse(exists, "Cousin should be removed");
    }
}
