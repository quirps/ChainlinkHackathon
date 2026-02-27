import { useEffect, useRef } from 'react'
import styles from './BondDetail.module.css'

export function BondDetail({ streamer, qty, onQtyChange, onClose, isConnected, onOpenAuth }) {
  const svgRef = useRef(null)

  // Draw sparkline when streamer changes
  useEffect(() => {
    if (!streamer || !svgRef.current) return
    const pts = []
    let price = streamer.price * (1 - streamer.chg / 100)
    for (let i = 0; i < 20; i++) {
      price += (Math.random() - 0.48) * 0.3 + (streamer.chg / 100 * streamer.price / 20)
      price = Math.max(price, streamer.price * 0.5)
      pts.push(price)
    }
    pts.push(streamer.price)
    const min   = Math.min(...pts)
    const max   = Math.max(...pts)
    const range = max - min || 0.01
    const W = 268, H = 52
    const coords = pts.map((p, i) =>
      `${(i / (pts.length - 1)) * W},${H - ((p - min) / range * (H - 6) + 3)}`
    )
    const color = streamer.chg >= 0 ? '#27C98A' : '#F03050'
    const gid   = 'cg_' + streamer.id
    svgRef.current.innerHTML = `
      <defs><linearGradient id="${gid}" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0%" stop-color="${color}" stop-opacity=".22"/>
        <stop offset="100%" stop-color="${color}" stop-opacity="0"/>
      </linearGradient></defs>
      <path d="M${coords.join(' L')} L${W},${H} L0,${H} Z" fill="url(#${gid})"/>
      <polyline points="${coords.join(' ')}" fill="none" stroke="${color}" stroke-width="1.5"/>`
  }, [streamer])

  if (!streamer) return null

  const total   = (streamer.price * qty).toFixed(2)
  const chgPos  = streamer.chg >= 0

  return (
    <div className={styles.panel}>
      <button className={styles.close} onClick={onClose}>✕</button>

      {/* Header */}
      <div className={styles.header}>
        <div className={styles.streamer}>
          <div className={styles.avi}>{streamer.avi}</div>
          <div>
            <div className={styles.name}>{streamer.name}</div>
            <div className={styles.handle}>massdx.gg/{streamer.id}</div>
          </div>
        </div>
        <div className={styles.statRow}>
          <Stat label="Price"    val={`$${streamer.price.toFixed(2)}`} />
          <Stat label="24h Chg"  val={`${streamer.chg > 0 ? '+' : ''}${streamer.chg.toFixed(1)}%`} color={chgPos ? 'up' : 'dn'} />
          <Stat label="Yield/mo" val={`${streamer.yield.toFixed(1)}%`} color="up" />
        </div>
      </div>

      <div className={styles.divider} />

      {/* Chart */}
      <div className={styles.sectionLabel}>Price History (7d)</div>
      <div className={styles.chart}>
        <svg ref={svgRef} viewBox="0 0 268 52" preserveAspectRatio="none" />
      </div>

      {/* Tranches */}
      <div className={styles.sectionLabel}>Tranches</div>
      <div className={styles.tranches}>
        {[1, 2, 3].map(t => (
          <div key={t} className={styles.trancheRow}>
            <span className={styles.trancheName}>Tranche {t}</span>
            <span className={styles.tranchePrice}>${(streamer.price * [0.70, 0.85, 1.00][t - 1]).toFixed(2)}</span>
            <span className={styles.trancheAvail}>
              {streamer.tranche === t ? `${streamer.supplyLeft} left` : 'Sold out'}
            </span>
          </div>
        ))}
      </div>

      <div className={styles.divider} />

      {/* Purchase */}
      <div className={styles.sectionLabel}>Purchase</div>
      <div className={styles.buyBlock}>
        <div className={styles.buyRow}>
          <input
            className={styles.qtyInput}
            type="number"
            value={qty}
            min={1}
            onChange={e => onQtyChange(Math.max(1, parseInt(e.target.value) || 1))}
          />
          <button className={styles.maxBtn} onClick={() => onQtyChange(streamer.supplyLeft)}>Max</button>
        </div>
        <div className={styles.total}>Total: <span>${total}</span></div>
        <button
          className={styles.confirmBtn}
          onClick={() => isConnected
            ? alert('Bond purchase → Dynamic wallet → gasless tx → BondRegistry')
            : onOpenAuth()
          }
        >
          {isConnected ? 'Purchase Bond →' : 'Connect to Buy'}
        </button>
      </div>
    </div>
  )
}

function Stat({ label, val, color }) {
  return (
    <div className={styles.stat}>
      <div className={`${styles.statVal} ${color ? styles[color] : ''}`}>{val}</div>
      <div className={styles.statLabel}>{label}</div>
    </div>
  )
}