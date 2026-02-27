import { StreamerIdentity } from './StreamerIdentity'
import { SupportStrip } from './SupportStrip'
import { Leaderboard } from './Leaderboard'
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './IdentityColumn.module.css'

export function IdentityColumn() {
  const brandColor = useStreamerStore((s) => s.streamer?.brandColor ?? '#D97B3A')

  return (
    <aside className={styles.col}>
      <div className={styles.amb} style={{ '--brand': brandColor }} />

      <StreamerIdentity />
      <StatusMessage />
      <SupportStrip />

      <div className={styles.spacer} />

      <div className={styles.bottomSection}>
        <Leaderboard />
      </div>
    </aside>
  )
}

function StatusMessage() {
  const statusMessage = useStreamerStore((s) => s.streamer?.statusMessage)
  if (!statusMessage) return null
  return <div className={styles.status}>{statusMessage}</div>
}