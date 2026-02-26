import { useUserStore } from '../../stores/useUserStore'
import styles from './TierDisplay.module.css'

export function TierDisplay() {
  const membership = useUserStore((s) => s.membership)
  if (!membership) return null

  return (
    <div className={styles.zone}>
      <div className={styles.inner}>
        <div className={styles.glyphWrap}>
          <span className={styles.glyph}>{membership.tierGlyph}</span>
          <div className={styles.tooltip} role="tooltip">
            <div className={styles.tooltipTitle}>
              {membership.tierName} — Lv {membership.level}
            </div>
            {membership.perks.map((perk, i) => (
              <div key={i} className={styles.perk}>
                <span className={styles.perkValue}>{perk.value}</span>
                {perk.label}
              </div>
            ))}
          </div>
        </div>
        <div className={styles.info}>
          <div className={styles.tierName}>{membership.tierName}</div>
          <div className={styles.tierLevel}>Level {membership.level} · Tier {membership.tier}</div>
        </div>
      </div>
    </div>
  )
}