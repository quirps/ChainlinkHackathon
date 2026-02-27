import clsx from 'clsx'
import { useUserStore } from '../../stores/useUserStore'
import styles from './AssetCard.module.css'

export function AssetCard({ asset, onPurchase }) {
  const level    = useUserStore((s) => s.membership?.level ?? 1)
  const isLocked = level < asset.levelRequired

  const priceDisplay =
    asset.priceType === 'mana'    ? asset.priceMana?.toLocaleString()
    : asset.priceType === 'credits' ? `$${(asset.priceCreditsCents / 100).toFixed(2)}`
    : '—'

  const priceUnit = asset.priceType === 'mana' ? 'Mana' : asset.priceType === 'credits' ? 'USD' : ''

  return (
    <article className={clsx(styles.card, styles[`rarity_${asset.rarity}`], isLocked && styles.locked)}>
      {/* Compact horizontal layout: emoji | info | price+btn */}
      <div className={styles.inner}>

        <span className={styles.glyph}>{asset.emoji}</span>

        <div className={styles.mid}>
          <div className={styles.topRow}>
            <span className={styles.name}>{asset.name}</span>
            <span className={clsx(styles.rarityDot, styles[`dot_${asset.rarity}`])} title={asset.rarity} />
          </div>
          {asset.sellerDisplayName ? (
            <div className={styles.seller}>
              Listed by <span className={styles.sellerName}>{asset.sellerDisplayName}</span>
            </div>
          ) : (
            <div className={styles.desc}>{asset.description}</div>
          )}
          {asset.xpOnPurchase > 0 && (
            <span className={styles.xpPill}>+{asset.xpOnPurchase} XP</span>
          )}
        </div>

        <div className={styles.right}>
          {isLocked ? (
            <div className={styles.lockInfo}>
              <span className={styles.lockIcon}>🔒</span>
              <span className={styles.lockLevel}>Lv {asset.levelRequired}</span>
            </div>
          ) : (
            <div className={styles.priceCol}>
              <span className={clsx(styles.price, asset.priceType === 'mana' && styles.priceMana)}>
                {priceDisplay}
              </span>
              <span className={styles.priceUnit}>{priceUnit}</span>
            </div>
          )}
          <button
            className={styles.btn}
            disabled={isLocked}
            onClick={() => !isLocked && onPurchase(asset)}
          >
            {isLocked ? 'Locked' : 'Get'}
          </button>
        </div>

      </div>
    </article>
  )
}