import { useState } from 'react'
import { useSocialAccounts, useDynamicContext } from '@dynamic-labs/sdk-react-core'
import { ProviderEnum } from '@dynamic-labs/types'
import styles from './AuthModal.module.css'

/**
 * Full-fat auth modal for the trader and market pages where users are more
 * likely to be web3-native and want to connect an existing wallet.
 *
 * Options:
 *   Social: Twitch, Google, Discord, Twitter/X
 *   Wallet: MetaMask, WalletConnect, Coinbase Wallet (via Dynamic's widget
 *           triggered headlessly via setShowAuthFlow)
 *
 * Props:
 *   onClose   fn
 */
export function Web3AuthModal({ onClose }) {
  const { signInWithSocialAccount, isProcessing, error } = useSocialAccounts()
  const { setShowAuthFlow } = useDynamicContext()
  const [activeTab, setActiveTab] = useState('social') // 'social' | 'wallet'

  const handleSocial = (provider) => {
    signInWithSocialAccount(provider)
  }

  const handleWalletConnect = () => {
    // Open Dynamic's native wallet selector — it handles MetaMask, WC, Coinbase
    // We close our modal first so there's no z-index conflict
    onClose()
    setShowAuthFlow(true)
  }

  return (
    <>
      <div className={styles.backdrop} onClick={onClose} />
      <div className={styles.modal} role="dialog" aria-label="Connect wallet or social">

        <div className={styles.ambOrb} style={{ '--orb': '#3AABF5' }} />

        <div className={styles.content}>
          <div className={styles.eyebrow}>Connect to MassDX</div>
          <h2 className={styles.headline}>Sign in to trade</h2>
          <p className={styles.sub}>
            Choose how you want to connect. Social login creates a smart wallet
            automatically. Existing wallets connect directly.
          </p>

          {/* Tab toggle */}
          <div className={styles.tabs}>
            <button
              className={`${styles.tabBtn} ${activeTab === 'social' ? styles.tabBtnOn : ''}`}
              onClick={() => setActiveTab('social')}
            >
              Social
            </button>
            <button
              className={`${styles.tabBtn} ${activeTab === 'wallet' ? styles.tabBtnOn : ''}`}
              onClick={() => setActiveTab('wallet')}
            >
              Wallet
            </button>
          </div>

          {activeTab === 'social' && (
            <div className={styles.socialGrid}>
              <SocialBtn
                provider={ProviderEnum.Twitch}
                label="Twitch"
                color="#9147FF"
                icon={<TwitchIcon />}
                onClick={handleSocial}
                disabled={isProcessing}
              />
              <SocialBtn
                provider={ProviderEnum.Google}
                label="Google"
                color="#EA4335"
                icon={<GoogleIcon />}
                onClick={handleSocial}
                disabled={isProcessing}
              />
              <SocialBtn
                provider={ProviderEnum.Discord}
                label="Discord"
                color="#5865F2"
                icon={<DiscordIcon />}
                onClick={handleSocial}
                disabled={isProcessing}
              />
              <SocialBtn
                provider={ProviderEnum.Twitter}
                label="X / Twitter"
                color="#1DA1F2"
                icon={<XIcon />}
                onClick={handleSocial}
                disabled={isProcessing}
              />
            </div>
          )}

          {activeTab === 'wallet' && (
            <div className={styles.walletTab}>
              <p className={styles.walletNote}>
                Connect MetaMask, WalletConnect, Coinbase Wallet, or any
                EVM-compatible wallet.
              </p>
              <button className={styles.walletConnectBtn} onClick={handleWalletConnect}>
                Browse wallets →
              </button>
            </div>
          )}

          {isProcessing && (
            <div className={styles.processing}>
              <span className={styles.spinner} />
              Connecting…
            </div>
          )}

          {error && (
            <div className={styles.errorMsg}>
              {error.message ?? 'Something went wrong. Please try again.'}
            </div>
          )}

          <div className={styles.fine}>
            New to crypto? Use social login — a smart wallet is created for you
            automatically with no fees or seed phrases.
          </div>
        </div>

        <button className={styles.closeBtn} onClick={onClose} aria-label="Close">✕</button>
      </div>
    </>
  )
}

function SocialBtn({ provider, label, color, icon, onClick, disabled }) {
  return (
    <button
      className={styles.socialBtn}
      style={{ '--social-color': color }}
      onClick={() => onClick(provider)}
      disabled={disabled}
    >
      <span className={styles.socialIcon}>{icon}</span>
      {label}
    </button>
  )
}

// ─── Icons ──────────────────────────────────────────────────

function TwitchIcon() {
  return (
    <svg width="14" height="15" viewBox="0 0 16 17" fill="none">
      <path d="M1.5 1l-1 2.5V14h3.5v2h2l2-2h3l4-4V1H1.5zm13 9l-2.5 2.5H8L6 14.5v-2H3V2.5h11.5V10z" fill="currentColor"/>
      <path d="M11 4.5h1.5V9H11V4.5zm-4 0H8.5V9H7V4.5z" fill="currentColor"/>
    </svg>
  )
}

function GoogleIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 18 18" fill="none">
      <path d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844a4.14 4.14 0 01-1.796 2.716v2.259h2.908c1.702-1.567 2.684-3.875 2.684-6.615z" fill="#4285F4"/>
      <path d="M9 18c2.43 0 4.467-.806 5.956-2.184l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 009 18z" fill="#34A853"/>
      <path d="M3.964 10.706A5.41 5.41 0 013.682 9c0-.593.102-1.17.282-1.706V4.962H.957A8.996 8.996 0 000 9c0 1.452.348 2.827.957 4.038l3.007-2.332z" fill="#FBBC05"/>
      <path d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 00.957 4.962L3.964 7.294C4.672 5.163 6.656 3.58 9 3.58z" fill="#EA4335"/>
    </svg>
  )
}

function DiscordIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
      <path d="M20.317 4.37a19.791 19.791 0 00-4.885-1.515.074.074 0 00-.079.037c-.21.375-.444.864-.608 1.25a18.27 18.27 0 00-5.487 0 12.64 12.64 0 00-.617-1.25.077.077 0 00-.079-.037A19.736 19.736 0 003.677 4.37a.07.07 0 00-.032.027C.533 9.046-.32 13.58.099 18.057a.082.082 0 00.031.057 19.9 19.9 0 005.993 3.03.078.078 0 00.084-.028c.462-.63.874-1.295 1.226-1.994a.076.076 0 00-.041-.106 13.107 13.107 0 01-1.872-.892.077.077 0 01-.008-.128 10.2 10.2 0 00.372-.292.074.074 0 01.077-.01c3.928 1.793 8.18 1.793 12.062 0a.074.074 0 01.078.01c.12.098.246.198.373.292a.077.077 0 01-.006.127 12.299 12.299 0 01-1.873.892.077.077 0 00-.041.107c.36.698.772 1.362 1.225 1.993a.076.076 0 00.084.028 19.839 19.839 0 006.002-3.03.077.077 0 00.032-.054c.5-5.177-.838-9.674-3.549-13.66a.061.061 0 00-.031-.03z"/>
    </svg>
  )
}

function XIcon() {
  return (
    <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-4.714-6.231-5.401 6.231H2.744l7.73-8.835L1.254 2.25H8.08l4.253 5.622zm-1.161 17.52h1.833L7.084 4.126H5.117z"/>
    </svg>
  )
}