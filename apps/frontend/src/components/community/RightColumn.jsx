import { TierDisplay } from './TierDisplay'
import { XPBar } from './XPBar'
import { ManaSession } from './ManaSession'
import { AchievementsBar } from './AchievementsBar'
import { XPBreakdown } from './XPBreakdown'
import { ActivityFeed } from './ActivityFeed'
import { useUserStore } from '../../stores/useUserStore'
import styles from './RightColumn.module.css'

export function RightColumn() {
  const membership = useUserStore((s) => s.membership)

  return (
    <aside className={styles.col}>

      {/* TOP: user progression (shown when authenticated) */}
      {membership ? (
        <div className={styles.topSection}>
          <TierDisplay />
          <XPBar />
          <div className={styles.divider} />
          <ManaSession />
          <AchievementsBar />
          <div className={styles.divider} />
          <XPBreakdown />
        </div>
      ) : (
        <div className={styles.guestPrompt}>
          <div className={styles.guestIcon}>⚔</div>
          <div className={styles.guestText}>Connect Twitch to track your progress</div>
        </div>
      )}

      {/* BOTTOM: live activity feed fills remaining space */}
      <ActivityFeed />
    </aside>
  )
}