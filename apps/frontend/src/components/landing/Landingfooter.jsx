import { Link } from 'react-router-dom'
import styles from './LandingFooter.module.css'

export function LandingFooter() {
  return (
    <footer className={styles.footer}>
      <div className={styles.inner}>
        <span className={styles.logo}>MassDX</span>
        <span className={styles.sub}>Chainlink Convergence 2025</span>
        <div className={styles.links}>
          <Link to="/market">Market</Link>
          <span>Docs</span>
          <span>GitHub</span>
        </div>
      </div>
    </footer>
  )
}