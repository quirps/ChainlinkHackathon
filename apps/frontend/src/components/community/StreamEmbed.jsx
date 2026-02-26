import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './StreamEmbed.module.css'

export function StreamEmbed() {
  const streamer = useStreamerStore((s) => s.streamer)
  if (!streamer?.isLive) return null

  const embedSrc = `https://player.twitch.tv/?channel=${streamer.twitchChannelName}&parent=${window.location.hostname}&muted=true`

  return (
    <div className={styles.zone}>
      <div className={styles.inner}>
        <iframe
          className={styles.embed}
          src={embedSrc}
          allowFullScreen
          title={`${streamer.twitchDisplayName} live stream`}
        />
      </div>
      <div className={styles.nudge}>
        ↗ Watching on Twitch directly earns{' '}
        <span className={styles.nudgeHighlight}>+10% bonus Mana</span> on all activity
      </div>
    </div>
  )
}