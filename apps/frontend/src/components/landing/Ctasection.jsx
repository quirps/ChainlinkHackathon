import { Link } from 'react-router-dom'
import styles from './CtaSection.module.css'

export function CtaSection({ onConnect }) {
  return (
    <section className={styles.section}>
      <div className={styles.amb} />
      <div className={styles.inner}>
        <div className={styles.eyebrow}>Get started today</div>
        <h2 className={styles.heading}>
          Built for communities.<br />Powered by Chainlink.
        </h2>
        <p className={styles.sub}>
          No wallet setup. No seed phrases. Connect Twitch and start earning Mana
          in the next stream you watch.
        </p>
        <div className={styles.actions}>
          <button className={styles.btnPrimary} onClick={onConnect}>
            Connect Twitch — it's free
          </button>
          <Link to="/market" className={styles.btnSecondary}>
            Browse the Market
          </Link>
        </div>
      </div>
    </section>
  )
}