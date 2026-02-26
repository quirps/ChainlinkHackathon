import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './SupportStrip.module.css'

export function SupportStrip() {
  const streamer = useStreamerStore((s) => s.streamer)
  if (!streamer) return null

  const subPrice = streamer.subscribePrice != null
    ? `$${(streamer.subscribePrice / 100).toFixed(2)} / mo`
    : null

  return (
    <div className={styles.strip}>
      {subPrice && (
        <button className={styles.subBtn}>
          Subscribe <span className={styles.price}>{subPrice}</span>
        </button>
      )}
      {streamer.bondsEnabled && (
        <button className={styles.bondBtn}>
          ◈ Back this creator <span className={styles.price}>Bonds</span>
        </button>
      )}
    </div>
  )
}