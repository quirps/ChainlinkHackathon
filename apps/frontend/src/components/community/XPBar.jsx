import { useEffect, useRef } from 'react'
import { useUserStore } from '../../stores/useUserStore'
import styles from './XPBar.module.css'

export function XPBar() {
  const membership = useUserStore((s) => s.membership)
  const fillRef    = useRef(null)

  const xp         = membership?.xpBalance ?? 0
  const nextLevelXp = membership?.nextLevelXp ?? 1
  const xpToNext   = membership?.xpToNextLevel ?? 0
  const fillPct    = Math.min(100, (xp / nextLevelXp) * 100)

  useEffect(() => {
    if (!fillRef.current) return
    const t = setTimeout(() => {
      if (fillRef.current) fillRef.current.style.width = `${fillPct}%`
    }, 200)
    return () => clearTimeout(t)
  }, [fillPct])

  if (!membership) return null

  return (
    <div className={styles.zone}>
      <div className={styles.nums}>
        <span className={styles.current}>{xp.toLocaleString()} / {nextLevelXp.toLocaleString()} XP</span>
        <span className={styles.nextLabel}>Lv {membership.level + 1}</span>
      </div>
      <div className={styles.track}>
        <div ref={fillRef} className={styles.fill} style={{ width: '0%' }} />
      </div>
      <div className={styles.sub}>
        <span className={styles.subXp}>{xpToNext.toLocaleString()} XP</span> to next level
      </div>
    </div>
  )
}