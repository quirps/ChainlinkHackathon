import { useState } from 'react'
import styles from './QuickBuy.module.css'

export function QuickBuy({ streamers }) {
  const [selectedId, setSelectedId] = useState('')
  const [qty, setQty]               = useState(1)

  return (
    <div className={styles.widget}>
      <div className={styles.label}>Quick Buy</div>
      <select
        className={styles.select}
        value={selectedId}
        onChange={e => setSelectedId(e.target.value)}
      >
        <option value="">Select streamer…</option>
        {streamers.map(s => (
          <option key={s.id} value={s.id}>{s.name}</option>
        ))}
      </select>
      <div className={styles.row}>
        <input
          className={styles.input}
          type="number"
          value={qty}
          min={1}
          onChange={e => setQty(Math.max(1, parseInt(e.target.value) || 1))}
        />
        <button className={styles.btn}>Buy Bond →</button>
      </div>
    </div>
  )
}