import { useStreamerStore } from '../../stores/useStreamerStore'
import { useUIStore } from '../../stores/useUIStore'
import styles from './AchievementsBar.module.css'

export function AchievementsBar() {
  const achievements  = useStreamerStore((s) => s.achievements)
  const openModal     = useUIStore((s) => s.openAchievementsModal)

  const claimableCount = achievements.filter((a) => a.status === 'claimable').length
  const earnedCount    = achievements.filter((a) => a.status === 'claimed' || a.status === 'claimable').length

  return (
    <button className={styles.bar} onClick={openModal} aria-label="View achievements">
      <span className={styles.icon}>🏆</span>
      <div className={styles.text}>
        <div className={styles.title}>Achievements</div>
        <div className={styles.sub}>
          {claimableCount > 0
            ? `${claimableCount} unclaimed · ${earnedCount} total earned`
            : `${earnedCount} earned`}
        </div>
      </div>
      {claimableCount > 0 && (
        <span className={styles.badge}>{claimableCount}</span>
      )}
    </button>
  )
}