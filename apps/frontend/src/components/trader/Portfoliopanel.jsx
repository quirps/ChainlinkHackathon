import styles from './PortfolioPanel.module.css'

export function PortfolioPanel({ myBonds }) {
  const total  = myBonds.reduce((s, b) => s + b.qty * b.current, 0)
  const cost   = myBonds.reduce((s, b) => s + b.qty * b.cost,    0)
  const pnl    = total - cost
  const pnlPct = cost > 0 ? (pnl / cost) * 100 : 0

  return (
    <div className={styles.panel}>
      <div className={styles.head}>
        <span>Portfolio</span>
        <span className={styles.action}>Details</span>
      </div>
      <div className={styles.body}>
        <div className={styles.total}>${total.toFixed(2)}</div>
        <div className={`${styles.pnl} ${pnl >= 0 ? styles.up : styles.dn}`}>
          {pnl >= 0 ? '+' : ''}${Math.abs(pnl).toFixed(2)} · {pnl >= 0 ? '+' : ''}{pnlPct.toFixed(1)}% all time
        </div>
        <div className={styles.bars}>
          {myBonds.map(b => {
            const pct = total > 0 ? Math.round((b.qty * b.current / total) * 100) : 0
            return (
              <div key={b.id} className={styles.barRow}>
                <span className={styles.barName}>{b.name}</span>
                <div className={styles.barTrack}>
                  <div className={styles.barFill} style={{ width: `${pct}%` }} />
                </div>
                <span className={styles.barPct}>{pct}%</span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}