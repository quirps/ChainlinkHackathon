import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './XPBreakdown.module.css'

export function XPBreakdown() {
  const entries = useStreamerStore((s) => s.xpBreakdown)
  if (!entries.length) return null

  return (
    <section className={styles.section}>
      <div className={styles.head}>XP Sources</div>
      <div className={styles.list}>
        {entries.map((entry) => (
          <div key={entry.label} className={styles.row}>
            <span className={styles.label}>{entry.label}</span>
            <div className={styles.barWrap}>
              <div className={styles.bar} style={{ width: `${entry.percentOfTotal}%` }} />
            </div>
            <span className={styles.val}>+{entry.amount.toLocaleString()}</span>
          </div>
        ))}
      </div>
    </section>
  )
}