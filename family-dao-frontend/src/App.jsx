import { useEffect, useState } from 'react'
import { ethers } from 'ethers'
import './App.css'

// Contract ABIs
import FamilyDAO from './contracts/FamilyDAO.json'
import FamilyNFT from './contracts/FamilyNFT.json'
import FamilyRegistry from './contracts/FamilyRegistry.json'

// Deployed contract addresses on Sepolia
import {
  FAMILY_NFT_ADDRESS,
  FAMILY_REGISTRY_ADDRESS,
  FAMILY_DAO_ADDRESS,
  RPC_URL
} from './constants';

// Sepolia RPC via GetBlock
const provider = new ethers.JsonRpcProvider(RPC_URL);


function App() {
  const [account, setAccount] = useState(null)
  const [error, setError] = useState(null)
  const [blockNumber, setBlockNumber] = useState(null)
  const [proposalCount, setProposalCount] = useState(null)

  const [daoContract, setDaoContract] = useState(null)
  const [nftContract, setNftContract] = useState(null)
  const [registryContract, setRegistryContract] = useState(null)

  const [newProposal, setNewProposal] = useState("")
  const [txStatus, setTxStatus] = useState(null)

  const connectWallet = async () => {
    if (!window.ethereum) {
      return setError("🦊 MetaMask is not installed.")
    }

    try {
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' })
      setAccount(accounts[0])
    } catch (err) {
      console.error(err)
      setError("Failed to connect wallet.")
    }
  }

  const createProposal = async () => {
    if (!daoContract || !account || !newProposal) return

    try {
      const signerProvider = new ethers.BrowserProvider(window.ethereum);
      const signer = await signerProvider.getSigner();

      const daoWithSigner = daoContract.connect(signer)

      const tx = await daoWithSigner.createProposal(newProposal)
      setTxStatus("📨 Waiting for transaction to confirm...")
      await tx.wait()
      setTxStatus("✅ Proposal submitted!")
      setNewProposal("") // reset input

      // Optional: update proposal count
      const updatedCount = await daoWithSigner.proposalCount()
      setProposalCount(updatedCount.toString())
    } catch (err) {
      console.error("❌ Error creating proposal:", err)
      setTxStatus("❌ Transaction failed.")
    }
  }

  useEffect(() => {
    const loadContracts = async () => {
      try {
        const block = await provider.getBlockNumber()
        setBlockNumber(block)

        const dao = new ethers.Contract(FAMILY_DAO_ADDRESS, FamilyDAO.abi, provider)
        const nft = new ethers.Contract(FAMILY_NFT_ADDRESS, FamilyNFT.abi, provider)
        const registry = new ethers.Contract(FAMILY_REGISTRY_ADDRESS, FamilyRegistry.abi, provider)

        setDaoContract(dao)
        setNftContract(nft)
        setRegistryContract(registry)

        console.log("✅ DAO loaded:", dao)
        console.log("✅ NFT loaded:", nft)
        console.log("✅ Registry loaded:", registry)

        const count = await dao.proposalCount()
        setProposalCount(count.toString())
        console.log("🗳️ Proposal Count:", count.toString())
      } catch (err) {
        console.error("❌ Error loading blockchain data:", err)
        setError("Could not fetch contract data.")
      }
    }

    loadContracts()
  }, [])

  const adminMintNFT = async () => {
    if (!nftContract || !account) return;
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const nftWithSigner = nftContract.connect(signer);
      const tx = await nftWithSigner.adminMint();
      await tx.wait();
      alert("✅ NFT successfully minted to your address!");
    } catch (err) {
      console.error("❌ Admin mint failed:", err);
      alert("❌ Admin mint failed.");
    }
  };


  return (
    <div className="app">
      <h1>👨‍👩‍👧‍👦 FamilyDAO Dashboard</h1>

      {account ? (
        <p>🔐 Connected wallet: <strong>{account}</strong></p>
      ) : (
        <button onClick={connectWallet}>🔌 Connect Wallet</button>
      )}


      {error && <p style={{ color: 'red' }}>{error}</p>}
      {blockNumber && <p>📦 Sepolia Block: {blockNumber}</p>}
      {proposalCount !== null && <p>🗳️ Total Proposals: {proposalCount}</p>}

      <div style={{ marginTop: "20px" }}>
        <h2>📝 Create New Proposal</h2>
        <input
          type="text"
          value={newProposal}
          onChange={(e) => setNewProposal(e.target.value)}
          placeholder="ADD_MEMBER:0x...:0x...:role"
          style={{ width: "400px", padding: "5px" }}
        />
        <button onClick={createProposal} style={{ marginLeft: "10px", padding: "6px 12px" }}>
          Submit Proposal
        </button>
        {txStatus && <p>{txStatus}</p>}
      </div>

      {account && (
        <button onClick={adminMintNFT}>🪙 Admin Mint NFT to Self</button>
      )}

      {account && daoContract && (
        <button onClick={async () => {
          try {
            const signer = new ethers.BrowserProvider(window.ethereum).getSigner();
            const daoWithSigner = (await daoContract).connect(await signer);
            const tx = await daoWithSigner.vote(0, true); // vote FOR proposal #0
            await tx.wait();
            alert("✅ Voted FOR proposal #0");
          } catch (err) {
            console.error("❌ Voting failed:", err);
            alert("❌ Voting failed");
          }
        }}>
          🗳️ Vote FOR Proposal #0
        </button>
      )}


    </div>
  )  
}

export default App
