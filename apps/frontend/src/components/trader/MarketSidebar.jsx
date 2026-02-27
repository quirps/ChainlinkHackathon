import styles from './MarketSidebar.module.css'

const CATEGORIES = ['All', 'FPS', 'RPG', 'Variety', 'IRL', 'Esports']

const CAT_CHG = {
  All: { val: '+2.4%', pos: true },
  FPS: { val: '+3.1%', pos: true },
  RPG: { val: '−0.8%', pos: false },
  Variety: { val: '+1.2%', pos: true },
  IRL: { val: '+0.0%', pos: null },
  Esports: { val: '+5.7%', pos: true },
}

export function MarketSidebar({ category, onCategory, myBonds, streamers, onSelectRow }) {
  return (
    <aside className={styles.sidebar}>
      {/* Indices */}
      <div className={styles.section}>
        <div className={styles.sectionHead}>Indices</div>
        {CATEGORIES.map(cat => {
          const meta = CAT_CHG[cat]
          return (
            <div
              key={cat}
              className={`${styles.item} ${category === cat ? styles.itemOn : ''}`}
              onClick={() => onCategory(cat)}
            >
              <span>{cat === 'All' ? 'All Markets' : cat}</span>
              <span className={`${styles.itemVal} ${meta.pos === true ? styles.up : meta.pos === false ? styles.dn : styles.neu}`}>
                {meta.val}
              </span>
            </div>
          )
        })}
      </div>

      {/* My Bonds */}
      <div className={styles.section}>
        <div className={styles.sectionHead}>Your Bonds</div>
        {myBonds.map(b => {
          const pnl = ((b.current - b.cost) / b.cost) * 100
          return (
            <div key={b.id} className={styles.bondItem} onClick={() => onSelectRow(b.id)}>
              <div className={styles.bondTop}>
                <span className={styles.bondName}>{b.name}</span>
                <span className={`${styles.bondPnl} ${pnl >= 0 ? styles.up : styles.dn}`}>
                  {pnl >= 0 ? '+' : ''}{pnl.toFixed(1)}%
                </span>
              </div>
              <div className={styles.bondBot}>
                <span className={styles.bondQty}>{b.qty}× bonds</span>
                <span className={styles.bondVal}>${(b.qty * b.current).toFixed(2)}</span>
              </div>
            </div>
          )
        })}
      </div>

      {/* Watchlist */}
      <div className={styles.section}>
        <div className={styles.sectionHead}>Watchlist</div>
        {['nightowltv', 'prism'].map(id => {
          const s = streamers.find(r => r.id === id)
          if (!s) return null
          return (
            <div key={id} className={styles.item} onClick={() => onSelectRow(id)}>
              <span>{s.name}</span>
              <span className={`${styles.itemVal} ${s.chg >= 0 ? styles.up : styles.dn}`}>
                {s.chg > 0 ? '+' : ''}{s.chg.toFixed(1)}%
              </span>
            </div>
          )
        })}
      </div>
    </aside>
  )
}