import { useStreamerStore } from '../../stores/useStreamerStore'
import { useUIStore } from '../../stores/useUIStore'
import { AssetCard } from './AssetCard'
import styles from './VaultGrid.module.css'

const FILTERS = [
  { label: 'Mana',    value: 'mana'    },
  { label: 'Credits', value: 'credits' },
  { label: 'All',     value: 'all'     },
]

export function VaultGrid({ onPurchase }) {
  const assets    = useStreamerStore((s) => s.assets)
  const filter    = useUIStore((s) => s.marketFilter)
  const setFilter = useUIStore((s) => s.setMarketFilter)

  const filtered = assets.filter((a) => {
    if (filter === 'all')     return true
    if (filter === 'mana')    return a.priceType === 'mana'    || a.priceType === 'both'
    if (filter === 'credits') return a.priceType === 'credits' || a.priceType === 'both'
    return true
  })

  return (
    <div className={styles.wrap}>
      <div className={styles.filterRow}>
        {FILTERS.map((f) => (
          <button
            key={f.value}
            className={`${styles.chip} ${filter === f.value ? styles.chipOn : ''}`}
            onClick={() => setFilter(f.value)}
          >
            {f.label}
          </button>
        ))}
      </div>

      {filtered.length === 0 ? (
        <div className={styles.empty}>No assets in this category</div>
      ) : (
        <div className={styles.grid}>
          {filtered.map((asset) => (
            <AssetCard key={asset.id} asset={asset} onPurchase={onPurchase} />
          ))}
        </div>
      )}
    </div>
  )
}