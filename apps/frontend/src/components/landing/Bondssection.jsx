import { Link } from 'react-router-dom'
import styles from './BondsSection.module.css'

const METRICS = [
  { num: '3.4%',  label: 'Avg monthly yield'       },
  { num: '1,000', label: 'Max supply per streamer'  },
  { num: '5%',    label: 'Revenue share pool'       },
]

const BOND_ROWS = [
  { label: 'Bond Price',    val: '$4.20',  up: false },
  { label: '24h Change',    val: '+4.2%',  up: true  },
  { label: 'Monthly Yield', val: '2.1%',   up: true  },
  { label: 'Holders',       val: '89',     up: false },
  { label: 'Supply Left',   val: '312',    up: false },
]

export function BondsSection() {
  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        <div className={styles.grid}>

          <div className={styles.copy}>
            <div className={styles.eyebrow}>Creator Bonds</div>
            <h2 className={styles.heading}>
              Own a piece of<br />
              <span className={styles.accent}>the economy</span>
            </h2>
            <p className={styles.desc}>
              Bonds are revenue-sharing instruments tied to a streamer's marketplace.
              Every purchase in their community — Mana or Credits — flows proportionally to bondholders.
              Three tranches. Limited supply. Earlier = cheaper.
            </p>
            <div className={styles.metrics}>
              {METRICS.map(m => (
                <div key={m.label} className={styles.metric}>
                  <span className={styles.metricNum}>{m.num}</span>
                  <span className={styles.metricLbl}>{m.label}</span>
                </div>
              ))}
            </div>
            <Link to="/market" className={styles.btn}>Browse Bonds →</Link>
          </div>

          <div className={styles.card}>
            <div className={styles.cardHeader}>
              <span className={styles.cardStreamer}>NightOwlTV</span>
              <span className={styles.cardTranche}>Tranche 1</span>
            </div>
            {BOND_ROWS.map(r => (
              <div key={r.label} className={styles.cardRow}>
                <span className={styles.cardLabel}>{r.label}</span>
                <span className={`${styles.cardVal} ${r.up ? styles.up : ''}`}>{r.val}</span>
              </div>
            ))}
            <div className={styles.cardChart}>
              <svg viewBox="0 0 200 40" preserveAspectRatio="none">
                <polyline
                  points="0,32 20,28 40,30 60,22 80,18 100,24 120,16 140,12 160,8 180,10 200,6"
                  fill="none"
                  stroke="var(--X)"
                  strokeWidth="1.5"
                />
              </svg>
            </div>
            <button className={styles.cardBtn}>Purchase Bond →</button>
          </div>

        </div>
      </div>
    </section>
  )
}