// StreamerIdentity.jsx
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './StreamerIdentity.module.css'

export function StreamerIdentity() {
  const streamer = useStreamerStore((s) => s.streamer)
  if (!streamer) return <div className={styles.skeleton} />

  const name    = streamer.twitchDisplayName
  const splitAt = Math.ceil(name.length * 0.55)
  const prefix  = name.slice(0, splitAt)
  const suffix  = name.slice(splitAt)

  return (
    <div className={styles.wrap}>
      <div className={styles.logoWrap}>
        <div className={styles.logo}>{streamer.twitchAvatarEmoji}</div>
      </div>
      <h1 className={styles.name}>
        {prefix}<em>{suffix}</em>
      </h1>
      {streamer.tagline && (
        <p className={styles.tagline}>"{streamer.tagline}"</p>
      )}
    </div>
  )
}