import { Link } from 'react-router-dom'
import styles from './LandingNav.module.css'

export function LandingNav({ scrolled, isConnected, onConnect }) {
  return (
    <nav className={`${styles.nav} ${scrolled ? styles.scrolled : ''}`}>
      <div className={styles.inner}>
        <span className={styles.logo}>MassDX</span>
        <div className={styles.links}>
          <Link to="/market" className={styles.link}>Market</Link>
          <span className={styles.link}>Bonds</span>
          <span className={styles.link}>Docs</span>
        </div>
        <div className={styles.right}>
          {isConnected
            ? <Link to="/streamers/nightowltv" className={styles.cta}>Go to Community →</Link>
            : <button className={styles.cta} onClick={onConnect}>Connect Twitch</button>
          }
        </div>
      </div>
    </nav>
  )
}