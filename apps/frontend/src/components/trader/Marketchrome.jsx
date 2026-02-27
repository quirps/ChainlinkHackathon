import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { useDynamicContext } from '@dynamic-labs/sdk-react-core'
import { useUserStore } from '../../stores/useUserStore'
import { useUIStore } from '../../stores/useUIStore'
import styles from './MarketChrome.module.css'

export function MarketChrome({ streamers }) {
  const user         = useUserStore(s => s.user)
  const logout       = useUserStore(s => s.logout)
  const openWeb3Auth = useUIStore(s => s.openWeb3AuthModal)
  const { user: dynamicUser, handleLogOut } = useDynamicContext()

  const isConnected = !!dynamicUser || !!user
  const mana        = user?.globalManaBalance ?? 0
  const credits     = user?.globalCreditBalanceCents ?? 0

  return (
    <header className={styles.chrome}>
      <Link to="/" className={styles.logo}>MassDX</Link>

      <nav className={styles.nav}>
        <Link to="/"       className={styles.navItem}>Community</Link>
        <Link to="/market" className={`${styles.navItem} ${styles.navOn}`}>Market</Link>
        <span              className={styles.navItem}>Portfolio</span>
      </nav>

      <Ticker streamers={streamers} />

      <div className={styles.right}>
        <Clock />
        {isConnected ? (
          <>
            <div className={styles.manaPill}>
              <span className={styles.manaIco}>✦</span>
              <span className={styles.manaAmt}>{mana.toLocaleString()}</span>
            </div>
            <div className={styles.credPill}>
              {(credits / 100).toLocaleString('en-US', { style: 'currency', currency: 'USD' })}
            </div>
            <div
              className={styles.avatar}
              onClick={() => { handleLogOut(); logout() }}
              title="Sign out"
            >
              {user?.twitchDisplayName?.[0]?.toUpperCase() ?? '?'}
            </div>
          </>
        ) : (
          <button className={styles.connectBtn} onClick={openWeb3Auth}>Connect</button>
        )}
      </div>
    </header>
  )
}

// ─── Ticker ───────────────────────────────────────────────────────────────────

function Ticker({ streamers }) {
  return (
    <div className={styles.ticker}>
      <div className={styles.tickerInner}>
        {[...streamers, ...streamers].map((s, i) => (
          <span key={i} className={styles.tickItem}>
            <span className={styles.tickName}>{s.id.toUpperCase()}</span>
            <span className={styles.tickPrice}>${s.price.toFixed(2)}</span>
            <span className={`${styles.tickChg} ${s.chg > 0 ? styles.up : s.chg < 0 ? styles.dn : styles.neu}`}>
              {s.chg > 0 ? '+' : ''}{s.chg.toFixed(1)}%
            </span>
          </span>
        ))}
      </div>
    </div>
  )
}

// ─── Clock ────────────────────────────────────────────────────────────────────

function Clock() {
  const [time, setTime] = useState('')

  useEffect(() => {
    const update = () => {
      const n  = new Date()
      const h  = n.getHours() % 12 || 12
      const m  = String(n.getMinutes()).padStart(2, '0')
      const s  = String(n.getSeconds()).padStart(2, '0')
      const ap = n.getHours() >= 12 ? 'PM' : 'AM'
      setTime(`${h}:${m}:${s} ${ap}`)
    }
    update()
    const id = setInterval(update, 1000)
    return () => clearInterval(id)
  }, [])

  return <span className={styles.clock}>{time}</span>
}