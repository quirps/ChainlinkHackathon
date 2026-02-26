import clsx from 'clsx'
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './InventoryGrid.module.css'

export function InventoryGrid() {
  const inventory = useStreamerStore((s) => s.userInventory)

  if (!inventory.length) {
    return (
      <div className={styles.empty}>
        <span className={styles.emptyGlyph}>✦</span>
        <p>No items yet — purchase assets from The Vault to build your collection.</p>
      </div>
    )
  }

  return (
    <div className={styles.grid}>
      {inventory.map((item) => (
        <div
          key={item.id}
          className={clsx(
            styles.slot,
            styles[`rarity_${item.rarity}`],
            item.isConsumed && styles.consumed,
            item.isListed  && styles.listed
          )}
        >
          <span className={styles.glyph}>{item.emoji}</span>
          <div className={styles.name}>{item.name}</div>
          {item.sellerDisplayName && (
            <div className={styles.seller}>from {item.sellerDisplayName}</div>
          )}
          {item.unrealizedGainMana > 0 && (
            <div className={styles.gain}>+{item.unrealizedGainMana.toLocaleString()}</div>
          )}
          <div className={styles.badges}>
            {item.isListed   && <span className={styles.badgeListed}>Listed</span>}
            {item.isActive   && <span className={styles.badgeActive}>Active</span>}
            {item.isConsumed && <span className={styles.badgeUsed}>Used</span>}
          </div>
        </div>
      ))}
    </div>
  )
}