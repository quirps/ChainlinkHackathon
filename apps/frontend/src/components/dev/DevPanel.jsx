import { useState } from 'react'
import { useStreamerStore } from '../../stores/useStreamerStore'
import { useUserStore } from '../../stores/useUserStore'
import { useUIStore } from '../../stores/useUIStore'
import styles from './DevPanel.module.css'

/**
 * Dev panel — only rendered when VITE_DEV_PANEL=true in .env
 * Toggle with the ⚙ button fixed to bottom-left.
 * Lets you poke state without a running backend.
 */
export function DevPanel() {
  if (import.meta.env.VITE_DEV_PANEL !== 'true') return null
  return <DevPanelInner />
}

function DevPanelInner() {
  const [open, setOpen] = useState(false)

  const streamer       = useStreamerStore((s) => s.streamer)
  const setLiveStatus  = useStreamerStore((s) => s.setLiveStatus)
  const addMana        = useUserStore((s) => s.addMana)
  const addXP          = useUserStore((s) => s.addXP)
  const prependActivity = useStreamerStore((s) => s.prependActivityEvent)
  const addToast       = useUIStore((s) => s.addToast)
  const openLevelUp    = useUIStore((s) => s.openLevelUpModal)
  const openAch        = useUIStore((s) => s.openAchievementsModal)

  const isLive = streamer?.isLive ?? false

  const fireActivity = () => {
    prependActivity({
      id: `dev-${Date.now()}`,
      displayName: 'dev_user',
      eventType: 'asset_purchased',
      subjectName: 'Curse Token',
      subjectRarity: 'legendary',
      subjectEmoji: '💀',
      detailText: 'acquired',
      timeAgo: 'now',
      avatarEmoji: '🛠',
    })
  }

  return (
    <>
      <button
        className={styles.toggle}
        onClick={() => setOpen((o) => !o)}
        title="Dev panel"
      >
        ⚙
      </button>

      {open && (
        <div className={styles.panel}>
          <div className={styles.head}>Dev Panel</div>

          <div className={styles.section}>
            <div className={styles.label}>Stream</div>
            <button
              className={`${styles.btn} ${isLive ? styles.btnDanger : styles.btnGood}`}
              onClick={() => setLiveStatus(!isLive, isLive ? null : 1420)}
            >
              {isLive ? '⏹ Go offline' : '▶ Go live'}
            </button>
          </div>

          <div className={styles.section}>
            <div className={styles.label}>Mana / XP</div>
            <div className={styles.row}>
              <button className={styles.btn} onClick={() => addMana(500, 'watch_time')}>+500 Mana</button>
              <button className={styles.btn} onClick={() => addXP(200)}>+200 XP</button>
            </div>
          </div>

          <div className={styles.section}>
            <div className={styles.label}>Modals</div>
            <div className={styles.row}>
              <button className={styles.btn} onClick={() => openLevelUp({ levelBefore: 12, levelAfter: 13, tierName: 'Keeper of Embers' })}>
                Level up
              </button>
              <button className={styles.btn} onClick={openAch}>
                Achievements
              </button>
            </div>
          </div>

          <div className={styles.section}>
            <div className={styles.label}>Feed / Toast</div>
            <div className={styles.row}>
              <button className={styles.btn} onClick={fireActivity}>Activity event</button>
              <button className={styles.btn} onClick={() => addToast({ icon: '✦', title: '+840 Mana', subtitle: 'Watch time bonus', type: 'mana' })}>
                Toast
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}