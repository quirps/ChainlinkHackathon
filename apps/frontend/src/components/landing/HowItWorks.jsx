import { Link } from 'react-router-dom'
import { MOCK_LANDING_DATA } from '../../lib/mockData'
import styles from './HowItWorks.module.css'

const STEPS = [
  { num: '1', title: 'Connect Twitch',      desc: 'Sign in with Twitch. A gasless wallet is created automatically — no seed phrase, no setup.'    },
  { num: '2', title: 'Watch & Earn Mana',   desc: 'Every minute watching a live stream earns Mana. Chat, activate assets, complete achievements.' },
  { num: '3', title: 'Spend in the Vault',  desc: 'Use Mana to buy Curses, Totems, Decrees. Assets that affect the stream in real time.'         },
  { num: '4', title: 'Build Your Position', desc: 'Hold bonds that pay yield on every community purchase. Or flip assets on the secondary market.' },
]

export function HowItWorks() {
  const streamers = MOCK_LANDING_DATA.liveStreamers

  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        <div className={styles.grid}>

          <div className={styles.left}>
            <div className={styles.eyebrow}>How it works</div>
            <h2 className={styles.heading}>
              Zero friction.<br />
              <span className={styles.accent}>Real stakes.</span>
            </h2>
            <div className={styles.steps}>
              {STEPS.map(step => (
                <div key={step.num} className={styles.step}>
                  <div className={styles.stepNum}>{step.num}</div>
                  <div>
                    <div className={styles.stepTitle}>{step.title}</div>
                    <div className={styles.stepDesc}>{step.desc}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className={styles.previewCard}>
            <div className={styles.previewHead}>
              <span className={styles.previewLabel}>Live Now</span>
              <span className={styles.liveDot} />
            </div>
            {streamers.map(s => (
              <Link
                key={s.id}
                to={`/streamers/${s.id}`}
                className={styles.streamerRow}
              >
                <div className={styles.streamerAvi}>{s.avi}</div>
                <div className={styles.streamerInfo}>
                  <span className={styles.streamerName}>{s.name}</span>
                  <span className={styles.streamerViewers}>
                    {s.viewers} {s.live ? 'watching' : 'offline'}
                  </span>
                </div>
                <div className={styles.bondInfo}>
                  <span className={styles.bondPrice}>{s.bond}</span>
                  <span className={`${styles.bondChg} ${s.pos ? styles.up : styles.dn}`}>{s.chg}</span>
                </div>
              </Link>
            ))}
            <Link to="/market" className={styles.viewAll}>View all streamers →</Link>
          </div>

        </div>
      </div>
    </section>
  )
}