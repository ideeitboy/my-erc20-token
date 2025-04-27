import { useEffect, useState } from 'react'
import { ethers } from 'ethers'
import './App.css'

import FamilyDAO from './contracts/FamilyDAO.json'
import FamilyNFT from './contracts/FamilyNFT.json'
import FamilyRegistry from './contracts/FamilyRegistry.json'
// import adminMint from "../../src/contracts/FamilyNFT.sol"

import {
  FAMILY_NFT_ADDRESS,
  FAMILY_REGISTRY_ADDRESS,
  FAMILY_DAO_ADDRESS,
  RPC_URL
} from './constants'

const provider = new ethers.JsonRpcProvider(RPC_URL)

function App() {
  const [account, setAccount] = useState(null)
  const [error, setError] = useState(null)
  const [blockNumber, setBlockNumber] = useState(null)
  const [daoContract, setDaoContract] = useState(null)
  const [nftContract, setNftContract] = useState(null)
  const [registryContract, setRegistryContract] = useState(null)
  const [proposalCount, setProposalCount] = useState(0)
  const [proposalType, setProposalType] = useState('')
  const [adminAddress, setAdminAddress] = useState('')
  const [newMember, setNewMember] = useState('')
  const [parentAddress, setParentAddress] = useState('')
  const [role, setRole] = useState('')
  const [metadataURI, setMetadataURI] = useState('')
  const [memberToRemove, setMemberToRemove] = useState('')
  const [txStatus, setTxStatus] = useState(null)
  const [proposal, setProposal] = useState(null)
  const [mintedNFTs, setMintedNFTs] = useState([])

  const connectWallet = async () => {
    if (!window.ethereum) return setError("🦊 MetaMask is not installed.")
    try {
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' })
      setAccount(accounts[0])
      setError(null)  // ✅ Clear error after successful connection
    } catch (err) {
      console.error(err)
      setError("Failed to connect wallet.")
    }
  }

  const handleCreateProposal = async () => {
    if (!daoContract || !account) return

    let proposalDescription = ''

    if (proposalType === "ADD_MEMBER") {
      if (!newMember || !parentAddress || !role || !metadataURI) {
        alert("Please fill out all fields for Add Member.")
        return
      }
      if (!ethers.isAddress(newMember) || !ethers.isAddress(parentAddress)) {
        alert("Invalid address format.")
        return
      }

      let finalMetadataURI = metadataURI.startsWith('ipfs://') ? metadataURI : `ipfs://${metadataURI}`
      proposalDescription = `ADD_MEMBER:${newMember}:${parentAddress}:${role}:${finalMetadataURI}`

      console.log("📜 Prepared ADD_MEMBER Proposal String:", proposalDescription); // 🖨️ here

    } else if (proposalType === "REMOVE_MEMBER") {
      if (!memberToRemove || !ethers.isAddress(memberToRemove)) {
        alert("Invalid address for removal.")
        return
      }
      proposalDescription = `REMOVE_MEMBER:${memberToRemove}`
    } else {
      alert("Invalid proposal type selected.")
      return
    }

    try {
      const signerProvider = new ethers.BrowserProvider(window.ethereum)
      const signer = await signerProvider.getSigner()
      const daoWithSigner = daoContract.connect(signer)

      const tx = await daoWithSigner.createProposal(proposalDescription)
      setTxStatus("📨 Waiting for transaction to confirm...")
      await tx.wait()
      setTxStatus("✅ Proposal submitted!")

      setProposalType("")
      setNewMember("")
      setParentAddress("")
      setRole("")
      setMetadataURI("")
      setMemberToRemove("")

      await fetchProposal()
    } catch (err) {
      console.error("❌ Error creating proposal:", err)
      setTxStatus("❌ Transaction failed.")
    }
  }

  const adminMintNFT = async () => {
    if (!nftContract || !account) return
    try {
      const signerProvider = new ethers.BrowserProvider(window.ethereum)
      const signer = await signerProvider.getSigner()
      const nftWithSigner = nftContract.connect(signer)
      const tx = await nftWithSigner.adminMint(adminAddress)
      await tx.wait()
      alert("✅ NFT successfully minted!")
      await loadMintedNFTs()
    } catch (err) {
      console.error("❌ Admin mint failed:", err)
      alert("❌ Admin mint failed.")
    }
  }

  const fetchProposal = async () => {
    if (!daoContract) return
    const count = await daoContract.proposalCount()
    const parsedCount = Number(count.toString())
    setProposalCount(parsedCount)
    if (parsedCount > 0) {
      const latestProposal = await daoContract.proposals(parsedCount - 1)
      setProposal(latestProposal)
    }
  }

  const voteOnProposal = async (support) => {
    if (!daoContract || !account || !proposal) return
    try {
      const signerProvider = new ethers.BrowserProvider(window.ethereum)
      const signer = await signerProvider.getSigner()
      const daoWithSigner = daoContract.connect(signer)
      const tx = await daoWithSigner.vote(proposal.id, support)
      await tx.wait()
      alert(`✅ Voted ${support ? 'FOR' : 'AGAINST'} proposal`)
    } catch (err) {
      console.error("❌ Voting failed:", err)
      alert("❌ Voting failed")
    }
  }

  const executeProposal = async () => {
    if (!daoContract || !account || !proposal) return
    try {
      const signerProvider = new ethers.BrowserProvider(window.ethereum)
      const signer = await signerProvider.getSigner()
      const daoWithSigner = daoContract.connect(signer)
      const tx = await daoWithSigner.executeProposal(proposal.id)
      await tx.wait()
      alert("✅ Proposal executed!")
      await fetchProposal()
      await loadMintedNFTs()
    } catch (err) {
      console.error("❌ Execution failed:", err)
      alert("❌ Failed to execute proposal.")
    }
  }

  const loadMintedNFTs = async () => {
    if (!nftContract) return
    try {
      const nextTokenId = await nftContract.nextTokenId()
      const parsedNextTokenId = parseInt(nextTokenId.toString())

      const nftList = [];
      for (let tokenId = 0; tokenId < parsedNextTokenId; tokenId++) {
        try {
          const owner = await nftContract.ownerOf(tokenId);
          if (owner !== ethers.ZeroAddress) {
            const rawURI = await nftContract.tokenURI(tokenId);
            let formattedURI = rawURI.startsWith('ipfs://') ? `https://ipfs.io/ipfs/${rawURI.split('ipfs://')[1]}` : rawURI;

            let metadata = {};
            try {
              const response = await fetch(formattedURI);
              metadata = await response.json();
            } catch (err) {
              console.warn(`⚠️ Failed to fetch metadata for token ${tokenId}:`, err);
              metadata = { name: "Unknown", description: "Error loading metadata", image: "" };
            }

            let finalImage = "";
            if (metadata.image) {
              finalImage = metadata.image.startsWith('ipfs://') ? `https://ipfs.io/ipfs/${metadata.image.split('ipfs://')[1]}` : metadata.image;
            }

            nftList.push({
              tokenId,
              tokenURI: formattedURI,
              image: finalImage,
              name: metadata.name || `Token #${tokenId}`,
              description: metadata.description || "No description"
            });
          }
        } catch (err) {
          // ownerOf failed ➔ token is burned ➔ skip
          console.log(`Token ID ${tokenId} is burned.`);
        }
      }
      setMintedNFTs(nftList);

    } catch (err) {
      console.error("Failed to load minted NFTs:", err)
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
  
        window.daoContract = dao
        window.nftContract = nft
        window.registryContract = registry
  
        console.log("✅ Contracts loaded")
  
      } catch (err) {
        console.error("❌ Error loading contracts:", err)
        setError("Could not load contracts.")
      }
    }
    loadContracts()
  }, [])
  
  useEffect(() => {
    const initializeData = async () => {
      if (nftContract && daoContract && blockNumber !== null) {   // <-- check block number too
        console.log("✅ Contracts fully loaded, fetching proposals and minted NFTs...")
        await loadMintedNFTs()
        await fetchProposal()
      }
    }
    initializeData()
  }, [nftContract, daoContract, blockNumber])
  
  

  useEffect(() => {
    if (txStatus) {
      const timeout = setTimeout(() => setTxStatus(null), 4000)
      return () => clearTimeout(timeout)
    }
  }, [txStatus])

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
      <p>🗳️ Total Proposals: {proposalCount}</p>

      {account && (
        <div style={{ marginTop: "20px", display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <h2>👤 Admin Address</h2>
          <input type="text" placeholder="Admin IPFS" value={adminAddress} onChange={(e) => setAdminAddress(e.target.value)} style={{ width: '500px' }} />
          </div>
      )}

      {account && (
        <button onClick={adminMintNFT} style={{ marginTop: '20px' }}>🪙 Admin Mint NFT to Self</button>
      )}

  
      {account && (
        <div style={{ marginTop: "20px", display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <h2>📜 Create a New Proposal</h2>

          <select value={proposalType} onChange={(e) => setProposalType(e.target.value)} style={{ width: '500px', marginBottom: '10px' }}>
            <option value="">Select Proposal Type</option>
            <option value="ADD_MEMBER">Add Member</option>
            <option value="REMOVE_MEMBER">Remove Member</option>
          </select>

          {proposalType === "ADD_MEMBER" && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', marginTop: '10px', width: '500px' }}>
              <input type="text" placeholder="New Member Address" value={newMember} onChange={(e) => setNewMember(e.target.value)} />
              <input type="text" placeholder="Parent Address" value={parentAddress} onChange={(e) => setParentAddress(e.target.value)} />
              <input type="text" placeholder="Role" value={role} onChange={(e) => setRole(e.target.value)} />
              <input type="text" placeholder="Metadata CID" value={metadataURI} onChange={(e) => setMetadataURI(e.target.value)} />
            </div>
          )}

          {proposalType === "REMOVE_MEMBER" && (
            <div style={{ marginTop: "10px", width: '500px' }}>
              <input type="text" placeholder="Member Address to Remove" value={memberToRemove} onChange={(e) => setMemberToRemove(e.target.value)} style={{ width: '100%' }} />
            </div>
          )}

          <button onClick={handleCreateProposal} style={{ marginTop: "10px" }}>
            📤 Submit Proposal
          </button>

          {txStatus && <p>{txStatus}</p>}
        </div>
      )}

      {account && proposal && (
        <div style={{ marginTop: "40px" }}>
          <h2>🗳️ Proposal Actions</h2>
          <button onClick={() => voteOnProposal(true)}>Vote FOR Proposal</button>
          <button onClick={() => voteOnProposal(false)}>Vote AGAINST Proposal</button>
          <button onClick={executeProposal} style={{ padding: "6px 12px" }}>Execute Proposal</button>
        </div>
      )}

      <h2 style={{ marginTop: "40px" }}>🖼️ Minted NFTs</h2>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '20px' }}>
        {mintedNFTs.map((nft) => (
          <div key={nft.tokenId} style={{ border: '1px solid gray', padding: '10px', width: '250px' }}>
            <p><strong>Name:</strong> {nft.name}</p>
            <p><strong>Description:</strong> {nft.description}</p>
            <p><strong>Token ID:</strong> {nft.tokenId}</p>
            <p><strong>Token URI:</strong> <a href={nft.tokenURI} target="_blank" rel="noreferrer">View Metadata</a></p>
            {nft.image ? (
              <img src={nft.image} alt={`NFT ${nft.tokenId}`} style={{ width: '100%', marginTop: '10px' }} />
            ) : (
              <p>No image available</p>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}

export default App
