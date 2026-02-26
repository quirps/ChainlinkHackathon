import { EthereumWalletConnectors } from '@dynamic-labs/ethereum'

// Set VITE_DYNAMIC_ENV_ID in your .env file.
// Get it from: https://app.dynamic.xyz/dashboard/developer
export const DYNAMIC_ENV_ID = import.meta.env.VITE_DYNAMIC_ENV_ID ?? 'YOUR_ENV_ID_HERE'
console.log(DYNAMIC_ENV_ID)
// Wallet connectors — EVM only for now (Chainlink runs on EVM)
export const WALLET_CONNECTORS = [EthereumWalletConnectors]

// Dynamic provider settings shared across all pages.
// Individual pages control WHICH auth methods are shown via our own modal UI,
// not via Dynamic's built-in widget — we use headless mode throughout.
export const DYNAMIC_SETTINGS = {
  environmentId: DYNAMIC_ENV_ID,
  walletConnectors: WALLET_CONNECTORS,

  // Disable Dynamic's default UI — we render our own modals
  cssOverrides: '',

  // Events — handled in AuthProvider
  events: {},
}