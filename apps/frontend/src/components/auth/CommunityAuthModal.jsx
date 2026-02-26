import { useSocialAccounts } from '@dynamic-labs/sdk-react-core'
import { ProviderEnum } from '@dynamic-labs/types'
import styles from './AuthModal.module.css'

/**
 * Shown on community pages when a visitor clicks "Connect" or tries to buy
 * an asset without being logged in.
 *
 * Community pages are streamer-first — the only login option is Twitch.
 * This makes sense because: Twitch identity = the community identity.
 * Wallet creation happens silently via Dynamic AA after login.
 *
 * Props:
 *   streamerName   string  — shown in the modal headline
 *   onClose        fn      — called when user dismisses
 *   returnPath     string  — not used here but passed through for future redirect
 */
export function CommunityAuthModal({ streamerName, onClose }) {
  const { signInWithSocialAccount, isProcessing, error } = useSocialAccounts()

  const handleTwitchLogin = () => {
    signInWithSocialAccount(ProviderEnum.Twitch)
    // Modal stays open while processing — AuthProvider closes it via
    // isAuthenticated state change (parent component watches that)
  }

  return (
    <>
      <div className={styles.backdrop} onClick={onClose} />
      <div className={styles.modal} role="dialog" aria-label="Connect to join">

        {/* Ambient glow */}
        <div className={styles.ambOrb} style={{ '--orb': '#9147FF' }} />

        <div className={styles.content}>
          <div className={styles.eyebrow}>Community Login</div>

          <h2 className={styles.headline}>
            Join{' '}
            <span className={styles.streamerName}>
              {streamerName ?? 'this stream'}
            </span>
          </h2>

          <p className={styles.sub}>
            Connect with Twitch to earn Mana, unlock assets, and participate
            in the economy. Your wallet is created automatically — no seed
            phrases, no gas fees.
          </p>

          <div className={styles.perks}>
            <div className={styles.perk}><span className={styles.perkIcon}>✦</span> Earn Mana by watching</div>
            <div className={styles.perk}><span className={styles.perkIcon}>✦</span> Buy and trade community assets</div>
            <div className={styles.perk}><span className={styles.perkIcon}>✦</span> Wallet created in the background</div>
          </div>

          <button
            className={styles.twitchBtn}
            onClick={handleTwitchLogin}
            disabled={isProcessing}
          >
            <TwitchIcon />
            {isProcessing ? 'Connecting…' : 'Continue with Twitch'}
          </button>

          {error && (
            <div className={styles.errorMsg}>
              {error.message ?? 'Something went wrong. Please try again.'}
            </div>
          )}

          <div className={styles.fine}>
            By connecting you agree to MassDX's terms. Your Twitch username
            becomes your community identity.
          </div>
        </div>

        <button className={styles.closeBtn} onClick={onClose} aria-label="Close">✕</button>
      </div>
    </>
  )
}

function TwitchIcon() {
  return (
    <svg width="16" height="17" viewBox="0 0 16 17" fill="none" aria-hidden="true">
      <path d="M1.5 1l-1 2.5V14h3.5v2h2l2-2h3l4-4V1H1.5zm13 9l-2.5 2.5H8L6 14.5v-2H3V2.5h11.5V10z" fill="currentColor"/>
      <path d="M11 4.5h1.5V9H11V4.5zm-4 0H8.5V9H7V4.5z" fill="currentColor"/>
    </svg>
  )
}