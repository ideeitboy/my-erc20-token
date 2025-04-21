import { JsonRpcProvider } from "ethers";

const rpcUrl = import.meta.env.VITE_SEPOLIA_RPC_URL;
export const provider = new JsonRpcProvider(rpcUrl);
