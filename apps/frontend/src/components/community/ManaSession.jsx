import { useUserStore } from '../../stores/useUserStore'
import styles from './ManaSession.module.css'

export function ManaSession() {
  const sessionManaGained = useUserStore((s) => s.sessionManaGained)
  const breakdown         = useUserStore((s) => s.sessionManaBreakdown)

  return (
    <div className={styles.zone}>
      <div className={styles.label}>Mana — This Session</div>
      <div className={styles.totalRow}>
        <div className={styles.totalNum}>+{sessionManaGained.toLocaleString()}</div>
        <div className={styles.totalUnit}>mana</div>
      </div>

      {breakdown.length > 0 ? (
        <div className={styles.sources}>
          {breakdown.map((src) => (
            <div key={src.source} className={styles.sourceRow}>
              <span className={styles.srcLabel}>{src.label}</span>
              <div className={styles.srcBar}>
                <div className={styles.srcFill} style={{ width: `${src.percentOfTotal}%` }} />
              </div>
              <span className={styles.srcVal}>+{src.amount.toLocaleString()}</span>
            </div>
          ))}
        </div>
      ) : (
        <div className={styles.empty}>Watch, chat, or activate items to earn Mana</div>
      )}
    </div>
  )
}