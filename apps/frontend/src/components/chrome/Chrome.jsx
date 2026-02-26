import { ManaFlask } from './ManaFlask'
import { useUserStore } from '../../stores/useUserStore'
import { useStreamerStore } from '../../stores/useStreamerStore'
import { useUIStore } from '../../stores/useUIStore'
import { useDynamicContext } from '@dynamic-labs/sdk-react-core'
import styles from './Chrome.module.css'

/**
 * Props:
 *   streamerChannelName  string | undefined
 *     — if present we're on a community page → Twitch-only auth modal
 *     — if absent we're on trader/market    → Web3 auth modal
 */
export function Chrome({ streamerChannelName }) {
  const user    = useUserStore((s) => s.user)
  const isLive  = useStreamerStore((s) => s.streamer?.isLive ?? false)

  const openCommunityAuth = useUIStore((s) => s.openCommunityAuthModal)
  const openWeb3Auth      = useUIStore((s) => s.openWeb3AuthModal)

  const { handleLogOut } = useDynamicContext()
  const logout           = useUserStore((s) => s.logout)

  const creditsCents   = user?.globalCreditBalanceCents ?? 0
  const creditsDisplay = (creditsCents / 100).toLocaleString('en-US', { style: 'currency', currency: 'USD' })
  const initials       = user?.twitchDisplayName?.slice(0, 1).toUpperCase() ?? '?'

  const handleConnectClick = () => {
    if (streamerChannelName) {
      openCommunityAuth()
    } else {
      openWeb3Auth()
    }
  }

  const handleAvatarClick = () => {
    // TODO: open profile dropdown — for now just log out
    handleLogOut()
    logout()
  }

  return (
    <header className={styles.chrome}>
      <span className={styles.logo}>MassDX</span>

      {streamerChannelName && (
        <div className={styles.crumb}>
          / <span className={styles.crumbChannel}>{streamerChannelName}</span>
        </div>
      )}

      {isLive && (
        <div className={styles.liveBadge}>
          <span className={styles.liveDot} />
          LIVE
        </div>
      )}

      <div className={styles.right}>
        {user ? (
          <>
            <ManaFlask />
            <div className={styles.credsPill}>
              {creditsDisplay}
              <span className={styles.credsAdd}>+ Add</span>
            </div>
            <div
              className={styles.avatar}
              title={`${user.twitchDisplayName} — click to sign out`}
              onClick={handleAvatarClick}
              role="button"
              tabIndex={0}
            >
              {initials}
            </div>
          </>
        ) : (
          <button className={styles.signInBtn} onClick={handleConnectClick}>
            {streamerChannelName ? 'Connect Twitch' : 'Connect'}
          </button>
        )}
      </div>
    </header>
  )
}