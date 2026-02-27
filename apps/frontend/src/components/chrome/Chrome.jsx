import { ManaFlask } from './ManaFlask'
import { useUserStore } from '../../stores/useUserStore'
import { useStreamerStore } from '../../stores/useStreamerStore'
import { useUIStore } from '../../stores/useUIStore'
import { useDynamicContext } from '@dynamic-labs/sdk-react-core'
import styles from './Chrome.module.css'

export function Chrome({ streamerChannelName }) {
  const storeUser = useUserStore((s) => s.user)
  const isLive    = useStreamerStore((s) => s.streamer?.isLive ?? false)

  const openCommunityAuth = useUIStore((s) => s.openCommunityAuthModal)
  const openWeb3Auth      = useUIStore((s) => s.openWeb3AuthModal)

  const { user: dynamicUser, handleLogOut } = useDynamicContext()
  const logout = useUserStore((s) => s.logout)

  // Use !!dynamicUser as the auth check — isAuthenticated is undefined in Dynamic SDK
  // Also accept storeUser as a fallback (already hydrated from a previous session)
  const isConnected = !!dynamicUser || !!storeUser

  // Prefer storeUser (backend-enriched) for display, fall back to raw Dynamic data
  const displayName = storeUser?.twitchDisplayName
    ?? storeUser?.twitchUsername
    ?? dynamicUser?.verifiedCredentials?.find((c) => c.oauthProvider === 'twitch')?.oauthUsername
    ?? dynamicUser?.alias
    ?? 'Connected'

  const creditsCents   = storeUser?.globalCreditBalanceCents ?? 0
  const creditsDisplay = (creditsCents / 100).toLocaleString('en-US', { style: 'currency', currency: 'USD' })

  const handleConnectClick = () => {
    streamerChannelName ? openCommunityAuth() : openWeb3Auth()
  }

  const handleSignOut = () => {
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
        {isConnected ? (
          <>
            <ManaFlask />
            <div className={styles.credsPill}>
              {creditsDisplay}
              <span className={styles.credsAdd}>+ Add</span>
            </div>
            <div
              className={styles.userPill}
              title="Click to sign out"
              onClick={handleSignOut}
              role="button"
              tabIndex={0}
            >
              <TwitchIcon />
              <span className={styles.userName}>{displayName}</span>
            </div>
          </>
        ) : (
          <button className={styles.signInBtn} onClick={handleConnectClick}>
            <TwitchIcon />
            {streamerChannelName ? 'Connect Twitch' : 'Connect'}
          </button>
        )}
      </div>
    </header>
  )
}

function TwitchIcon() {
  return (
    <svg className={styles.twitchIcon} viewBox="0 0 16 17" fill="none" aria-hidden="true">
      <path d="M1.5 1l-1 2.5V14h3.5v2h2l2-2h3l4-4V1H1.5zm13 9l-2.5 2.5H8L6 14.5v-2H3V2.5h11.5V10z" fill="currentColor"/>
      <path d="M11 4.5h1.5V9H11V4.5zm-4 0H8.5V9H7V4.5z" fill="currentColor"/>
    </svg>
  )
}