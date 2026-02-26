import { ManaFlask } from './ManaFlask'
import { useUserStore } from '../../stores/useUserStore'
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './Chrome.module.css'

export function Chrome({ streamerChannelName }) {
  const user    = useUserStore((s) => s.user)
  const isLive  = useStreamerStore((s) => s.streamer?.isLive ?? false)

  const creditsCents   = user?.globalCreditBalanceCents ?? 0
  const creditsDisplay = (creditsCents / 100).toLocaleString('en-US', { style: 'currency', currency: 'USD' })
  const initials       = user?.twitchDisplayName?.slice(0, 1).toUpperCase() ?? '?'

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
            <div className={styles.avatar} title={user.twitchDisplayName}>{initials}</div>
          </>
        ) : (
          <button className={styles.signInBtn}>Connect Twitch</button>
        )}
      </div>
    </header>
  )
}