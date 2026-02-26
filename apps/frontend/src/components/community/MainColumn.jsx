import { StreamEmbed } from './StreamEmbed'
import { VaultGrid } from './VaultGrid'
import { ProgressionTrack } from './ProgressionTrack'
import { InventoryGrid } from './InventoryGrid'
import { useUIStore } from '../../stores/useUIStore'
import { useStreamerStore } from '../../stores/useStreamerStore'
import { useUserStore } from '../../stores/useUserStore'
import { api } from '../../lib/api'
import styles from './MainColumn.module.css'

export function MainColumn() {
  const activeTab   = useUIStore((s) => s.activeTab)
  const setActiveTab = useUIStore((s) => s.setActiveTab)
  const addToast    = useUIStore((s) => s.addToast)
  const inventory   = useStreamerStore((s) => s.userInventory)
  const addUserAsset = useStreamerStore((s) => s.addUserAsset)
  const deductMana  = useUserStore((s) => s.deductMana)

  const handlePurchase = async (asset) => {
    const currency = asset.priceType === 'credits' ? 'credits' : 'mana'
    const result   = await api.purchaseAsset(asset.id, currency)

    if (result.error) {
      addToast({ icon: '✕', title: 'Purchase failed', subtitle: result.error.message, type: 'error' })
      return
    }

    addUserAsset(result.data.userAsset)
    if (currency === 'mana' && asset.priceMana) deductMana(asset.priceMana)

    addToast({
      icon: asset.emoji,
      title: `${asset.name} acquired`,
      subtitle: result.data.xpGranted > 0 ? `+${result.data.xpGranted} XP` : 'Added to your inventory',
      type: 'xp',
    })
  }

  return (
    <main className={styles.col}>
      <StreamEmbed />

      <div className={styles.tabRow}>
        <button
          className={`${styles.tab} ${activeTab === 'market' ? styles.tabOn : ''}`}
          onClick={() => setActiveTab('market')}
        >
          Market
        </button>
        <button
          className={`${styles.tab} ${activeTab === 'inventory' ? styles.tabOn : ''}`}
          onClick={() => setActiveTab('inventory')}
        >
          Inventory
          {inventory.length > 0 && (
            <span className={styles.tabCount}>{inventory.length}</span>
          )}
        </button>
      </div>

      <div className={styles.tabContent}>
        {activeTab === 'market' && (
          <>
            <VaultGrid onPurchase={handlePurchase} />
            <ProgressionTrack />
          </>
        )}
        {activeTab === 'inventory' && <InventoryGrid />}
      </div>
    </main>
  )
}