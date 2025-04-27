## Foundry
**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**
Foundry consists of:
-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.
## Documentation
https://book.getfoundry.sh/

# Family NFT Project (Foundry)

Family NFT Project is a fully decentralized application (dApp) that allows a family to manage its membership, heritage, and legacy through blockchain-based governance and NFT identity tokens.

### This project consists of:

- FamilyDAO.sol – A decentralized autonomous organization (DAO) contract where family members can propose, vote, and execute membership changes.
- FamilyRegistry.sol – A family tree registry smart contract that manages member roles, parent-child relationships, and metadata.
- FamilyNFT.sol – An ERC-721 NFT contract where each family member holds a non-transferable membership NFT linked to their identity metadata.
- FamilyDAO.sol – A decentralized autonomous organization (DAO) smart contract where family members can create, vote on, and execute proposals for membership management.
- FamilyRegistry.sol – A smart contract maintaining a family tree, tracking relationships (parent/child) and storing roles and IPFS metadata URIs for each member.
- FamilyNFT.sol – An ERC-721 NFT contract representing each family member as a unique non-transferable identity NFT linked to IPFS metadata.
- App.jsx – The main React frontend file that connects to smart contracts, handles wallet login, proposal creation, voting, NFT minting, and displays live blockchain data to users.
- constants.js – A configuration file containing deployed smart contract addresses and RPC URLs used by the frontend to connect to the blockchain.
- .env – Environment variable storage containing private keys, RPC API keys, and sensitive deployment information (never commit this to GitHub!).
- FamilyDAO.t.sol – A Foundry-based Solidity test suite that verifies FamilyDAO’s core proposal logic, voting process, and successful member addition/removal workflows.
- FamilyNFT_Registry.t.sol – A Foundry-based Solidity test suite that verifies NFT minting conditions, registry parent-child enforcement, and prevents unauthorized minting.
- React Frontend (Vite + Ethers.js) – A simple dashboard to interact with the contracts (propose new members, vote, mint NFTs, display family NFTs).
- IPFS Metadata Hosting – Member profile metadata and images are permanently stored via IPFS for decentralized access.
- Sepolia Testnet Deployment – All contracts are deployed and tested on the Ethereum Sepolia test network.

### Features

- NFT-Gated Governance: Only NFT holders can submit proposals, vote, and execute DAO actions.
- Two Types of Proposals:
    - ADD_MEMBER – Add a new family member by proposing their address, parent, role, and metadata CID.
    - REMOVE_MEMBER – Propose to remove a family member from the registry.
- Full On-Chain Voting: One address, one vote per proposal. Majority voting determines proposal outcome.
- Family Tree Relationship Management: Parent/child links and roles are recorded permanently on-chain.
- Decentralized Metadata: Family stories, profiles, and photos are uploaded to IPFS and linked to NFTs.
- Frontend Web Dashboard:
    - Connect wallet via MetaMask
    - Create new proposals
    - Vote on existing proposals
    - Execute successful proposals
    - View all minted NFTs with names, descriptions, and images

# Useful Commands 
### Build

```shell
$ forge build
```

### Test

```shell
$ forge test -vvvv
```

### Deploy Script Full Featured

```shell
$ forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --private-key $PRIVATE_KEY 
```

### Moving contract JSON files 

```shell
$ cp out/FamilyNFT.sol/FamilyNFT.json family-dao-frontend/src/contracts/FamilyNFT.json
cp out/FamilyDAO.sol/FamilyDAO.json family-dao-frontend/src/contracts/FamilyDAO.json
cp out/FamilyRegistry.sol/FamilyRegistry.json family-dao-frontend/src/contracts/FamilyRegistry.json
```

### Run Frontend Environment 

```shell
$ cd family-dao-frontend 
$ npm run dev
```

### Github Commit Commands 

```shell
$ git status
git add .
git commit -m "Make changes to display"
git push
```

