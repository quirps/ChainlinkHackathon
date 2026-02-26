// Leaderboard.jsx
import clsx from 'clsx'
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './Leaderboard.module.css'

export function Leaderboard() {
  const entries = useStreamerStore((s) => s.leaderboard)

  return (
    <section className={styles.section}>
      <div className={styles.head}>Leaderboard</div>
      <div className={styles.list}>
        {entries.map((entry) => (
          <div key={entry.userId} className={clsx(styles.row, entry.isCurrentUser && styles.you)}>
            <span className={styles.rank}>
              {entry.rank <= 3 ? ['🥇','🥈','🥉'][entry.rank - 1] : entry.rank}
            </span>
            <span className={styles.avi}>{entry.avatarEmoji}</span>
            <div className={styles.info}>
              <span className={styles.name}>{entry.displayName}</span>
              <span className={styles.tier}>{entry.tierName}</span>
            </div>
            <div className={styles.right}>
              <span className={styles.level}>Lv {entry.level}</span>
              <span className={styles.xp}>{(entry.xpBalance / 1000).toFixed(1)}k XP</span>
            </div>
          </div>
        ))}
      </div>
    </section>
  )
}