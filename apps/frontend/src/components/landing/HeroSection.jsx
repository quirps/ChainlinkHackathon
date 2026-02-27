import { Link } from 'react-router-dom'
import styles from './HeroSection.module.css'

const STATS = [
  { num: '14,208', label: 'Active viewers'    },
  { num: '$247K',  label: 'Bond value locked' },
  { num: '89',     label: 'Streamers live'    },
  { num: '3.4%',   label: 'Avg monthly yield' },
]

const PREVIEW_ITEMS = [
  { emoji: '💀', name: 'Curse Token',  price: '840 Mana',   rarity: 'rare'      },
  { emoji: '🌀', name: 'Void Omen',    price: '$2.40',      rarity: 'epic'      },
  { emoji: '⚡', name: 'Storm Decree', price: '1,200 Mana', rarity: 'legendary' },
]

export function HeroSection({ onConnect }) {
  return (
    <section className={styles.hero}>
      <div className={styles.amb} />
      <div className={styles.grid} />

      <div className={styles.copy}>
        <div className={styles.eyebrow}>
          <span className={styles.eyebrowDot} />
          Chainlink Convergence 2025
        </div>

        <h1 className={styles.headline}>
          <span className={styles.h1}>The community layer</span>
          <span className={styles.h2}>for <span className={styles.accent}>streamers</span></span>
        </h1>

        <p className={styles.sub}>
          Earn Mana watching streams. Spend it on assets that <strong>do things</strong> in real time.
          Hold bonds. Earn yield on every purchase in a creator's economy.
        </p>

        <div className={styles.actions}>
          <button className={styles.btnPrimary} onClick={onConnect}>
            Connect Twitch — it's free
          </button>
          <Link to="/market" className={styles.btnSecondary}>
            Explore the Market →
          </Link>
        </div>

        <div className={styles.stats}>
          {STATS.map(s => (
            <div key={s.label} className={styles.stat}>
              <span className={styles.statNum}>{s.num}</span>
              <span className={styles.statLbl}>{s.label}</span>
            </div>
          ))}
        </div>
      </div>

      <div className={styles.preview}>
        <div className={styles.previewHeader}>
          <div className={styles.previewAvi}>🦉</div>
          <div>
            <div className={styles.previewName}>NightOwlTV</div>
            <div className={styles.previewSub}>FPS · 14,208 watching</div>
          </div>
          <div className={styles.liveBadge}>
            <div className={styles.liveDot} />
            LIVE
          </div>
        </div>

        <div className={styles.xpRow}>
          <span className={styles.xpLabel}>Lv 8 · Keeper</span>
          <span className={styles.xpPct}>67%</span>
        </div>
        <div className={styles.xpTrack}>
          <div className={styles.xpFill} style={{ width: '67%' }} />
        </div>

        <div className={styles.items}>
          {PREVIEW_ITEMS.map(item => (
            <div key={item.name} className={styles.item}>
              <span className={styles.itemEmoji}>{item.emoji}</span>
              <div className={styles.itemInfo}>
                <span className={`${styles.itemName} ${styles[item.rarity]}`}>{item.name}</span>
                <span className={styles.itemPrice}>{item.price}</span>
              </div>
              <button className={styles.itemBtn}>Get</button>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}