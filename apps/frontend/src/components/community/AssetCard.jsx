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

  const priceUnit =
    asset.priceType === 'mana' ? 'Mana' : asset.priceType === 'credits' ? 'USD' : ''

  return (
    <article className={clsx(styles.card, styles[`rarity_${asset.rarity}`], isLocked && styles.locked)}>
      <div className={styles.vis}>
        <span className={styles.glyph}>{asset.emoji}</span>
        <span className={clsx(styles.rarityMark, styles[`rarity_${asset.rarity}`])}>
          {asset.rarity}
        </span>
      </div>

      <div className={styles.body}>
        {asset.sellerDisplayName && (
          <div className={styles.sellerBadge}>
            Listed by <span className={styles.sellerName}>{asset.sellerDisplayName}</span>
          </div>
        )}
        <div className={styles.name}>{asset.name}</div>
        <div className={styles.desc}>{asset.description}</div>
        {asset.xpOnPurchase > 0 && (
          <div className={styles.xpPill}>+{asset.xpOnPurchase} XP</div>
        )}

        <div className={styles.foot}>
          <div>
            {isLocked ? (
              <>
                <div className={styles.priceNum}>🔒 Lvl {asset.levelRequired}</div>
                <div className={styles.priceUnit}>required</div>
              </>
            ) : (
              <>
                <div className={clsx(styles.priceNum, asset.priceType === 'mana' && styles.priceNumMana)}>
                  {priceDisplay}
                </div>
                <div className={styles.priceUnit}>{priceUnit}</div>
              </>
            )}
          </div>
          <button
            className={styles.acquireBtn}
            disabled={isLocked}
            onClick={() => !isLocked && onPurchase(asset)}
          >
            {isLocked ? 'Locked' : 'Acquire'}
          </button>
        </div>
      </div>
    </article>
  )
}