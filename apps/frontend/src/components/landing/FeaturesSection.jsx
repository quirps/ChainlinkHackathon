import styles from './FeaturesSection.module.css'

const FEATURES = [
  {
    num: '01', emoji: '⚔',
    title: 'Community Assets',
    desc:  "Curses, Totems, Decrees — digital assets that do things inside a streamer's world. Buy with Mana you earn just by watching.",
    tag: 'Community', tagType: 'brand',
  },
  {
    num: '02', emoji: '📈',
    title: 'Creator Bonds',
    desc:  "Revenue-sharing bonds tied to a streamer's marketplace. Hold them, earn yield on every purchase made in their community.",
    tag: 'Finance', tagType: 'green',
  },
  {
    num: '03', emoji: '🔄',
    title: 'Secondary Market',
    desc:  'Trade assets between community members. List items from your inventory, set your price in Mana. Gasless transactions.',
    tag: 'Market', tagType: 'mana',
  },
]

export function FeaturesSection() {
  return (
    <section className={styles.section}>
      <div className={styles.inner}>
        <div className={styles.eyebrow}>
          <span>What MassDX does</span>
        </div>
        <div className={styles.grid}>
          {FEATURES.map(f => (
            <div key={f.num} className={styles.card}>
              <div className={styles.num}>{f.num}</div>
              <div className={styles.emoji}>{f.emoji}</div>
              <div className={styles.title}>{f.title}</div>
              <div className={styles.desc}>{f.desc}</div>
              <span className={`${styles.tag} ${styles[f.tagType]}`}>{f.tag}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}