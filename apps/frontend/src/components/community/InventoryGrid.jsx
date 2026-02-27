import { useState } from 'react'
import clsx from 'clsx'
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './InventoryGrid.module.css'

const TABS = [
  { label: 'All',    value: 'all'    },
  { label: 'Listed', value: 'listed' },
  { label: 'Active', value: 'active' },
]

export function InventoryGrid() {
  const inventory  = useStreamerStore((s) => s.userInventory)
  const [tab, setTab] = useState('all')

  const filtered = inventory.filter((item) => {
    if (tab === 'listed') return item.isListed
    if (tab === 'active') return item.isActive
    return true
  })

  const listedCount = inventory.filter((i) => i.isListed).length

  if (!inventory.length) {
    return (
      <div className={styles.empty}>
        <span className={styles.emptyGlyph}>✦</span>
        <p>No items yet — purchase assets from the Market to build your collection.</p>
      </div>
    )
  }

  return (
    <div className={styles.wrap}>
      {/* Tab filter */}
      <div className={styles.tabRow}>
        {TABS.map((t) => (
          <button
            key={t.value}
            className={clsx(styles.tab, tab === t.value && styles.tabOn)}
            onClick={() => setTab(t.value)}
          >
            {t.label}
            {t.value === 'listed' && listedCount > 0 && (
              <span className={styles.tabBadge}>{listedCount}</span>
            )}
          </button>
        ))}
      </div>

      {filtered.length === 0 ? (
        <div className={styles.tabEmpty}>No {tab} items</div>
      ) : (
        <div className={styles.grid}>
          {filtered.map((item) => (
            <InventorySlot key={item.id} item={item} />
          ))}
        </div>
      )}
    </div>
  )
}

function InventorySlot({ item }) {
  return (
    <div className={clsx(
      styles.slot,
      styles[`rarity_${item.rarity}`],
      item.isConsumed && styles.consumed,
      item.isListed   && styles.listed,
    )}>
      <div className={styles.slotTop}>
        <span className={styles.glyph}>{item.emoji}</span>
        {item.quantity > 1 && (
          <span className={styles.qty}>×{item.quantity}</span>
        )}
      </div>

      <div className={styles.slotName}>{item.name}</div>

      {/* Show seller username prominently if this is a secondary market item */}
      {item.sellerDisplayName && (
        <div className={styles.sellerRow}>
          <span className={styles.sellerIcon}>↖</span>
          <span className={styles.sellerName}>{item.sellerDisplayName}</span>
        </div>
      )}

      {item.unrealizedGainMana > 0 && (
        <div className={styles.gain}>+{item.unrealizedGainMana.toLocaleString()} Mana</div>
      )}

      <div className={styles.badges}>
        {item.isListed   && <span className={clsx(styles.badge, styles.badgeListed)}>Listed</span>}
        {item.isActive   && <span className={clsx(styles.badge, styles.badgeActive)}>Active</span>}
        {item.isConsumed && <span className={clsx(styles.badge, styles.badgeUsed)}>Used</span>}
      </div>
    </div>
  )
}