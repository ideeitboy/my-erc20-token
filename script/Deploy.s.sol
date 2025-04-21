// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/forge-std/src/Script.sol";
import "../src/contracts/FamilyDAO.sol";
import "../src/contracts/FamilyRegistry.sol";
import "../src/contracts/FamilyNFT.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy FamilyRegistry first
        FamilyRegistry registry = new FamilyRegistry();

        // Deploy FamilyNFT with registry address
        FamilyNFT nft = new FamilyNFT("Family Legacy", "FAM", address(registry));

        // Deploy FamilyDAO with references to NFT and registry
        FamilyDAO dao = new FamilyDAO(address(nft), registry);

        // 🔐 Let NFT know who the DAO is
        nft.setFamilyDAO(address(dao));

        console.log("FamilyNFT deployed at:");
        console.log(address(nft));

        console.log("FamilyRegistry deployed at:");
        console.log(address(registry));

        console.log("FamilyDAO deployed at:");
        console.log(address(dao));

        vm.stopBroadcast();
    }
}
