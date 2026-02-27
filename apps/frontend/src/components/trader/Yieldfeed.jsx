import styles from './YieldFeed.module.css'

export function YieldFeed({ events }) {
  return (
    <div className={styles.feed}>
      <div className={styles.head}><span>Yield Feed</span></div>
      <div className={styles.list}>
        {events.map((e, i) => (
          <div key={i} className={styles.item}>
            <div className={`${styles.dot} ${e.type === 'up' ? styles.dotUp : e.type === 'dn' ? styles.dotDn : styles.dotNeu}`} />
            <div className={styles.body}>
              <span className={styles.actor}>{e.actor}</span>
              {' '}<span className={styles.action}>{e.action}</span>
              {' — '}<span className={e.type === 'up' ? styles.up : styles.action}>{e.detail}</span>
            </div>
            <span className={styles.time}>{e.time}</span>
          </div>
        ))}
      </div>
    </div>
  )
}