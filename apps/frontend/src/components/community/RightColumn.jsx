import { Leaderboard } from './Leaderboard'
import { XPBreakdown } from './XPBreakdown'
import { ActivityFeed } from './ActivityFeed'
import styles from './RightColumn.module.css'

export function RightColumn() {
  return (
    <aside className={styles.col}>
      <Leaderboard />
      <XPBreakdown />
      <ActivityFeed />
    </aside>
  )
}