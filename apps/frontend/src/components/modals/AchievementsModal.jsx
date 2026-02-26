import { useStreamerStore } from '../../stores/useStreamerStore'
import { useUIStore } from '../../stores/useUIStore'
import { useUserStore } from '../../stores/useUserStore'
import { api } from '../../lib/api'
import styles from './AchievementsModal.module.css'
import clsx from 'clsx'

const SECTIONS = [
  { label: 'Ready to claim', statuses: ['claimable']   },
  { label: 'In progress',    statuses: ['in_progress'] },
  { label: 'Earned',         statuses: ['claimed']     },
  { label: 'Locked',         statuses: ['locked']      },
]

export function AchievementsModal() {
  const isOpen           = useUIStore((s) => s.achievementsModalOpen)
  const close            = useUIStore((s) => s.closeAchievementsModal)
  const addToast         = useUIStore((s) => s.addToast)
  const achievements     = useStreamerStore((s) => s.achievements)
  const updateAchievement = useStreamerStore((s) => s.updateAchievement)
  const streamer         = useStreamerStore((s) => s.streamer)
  const addMana          = useUserStore((s) => s.addMana)
  const addXP            = useUserStore((s) => s.addXP)

  if (!isOpen) return null

  const handleClaim = async (ach) => {
    if (!streamer) return
    const result = await api.claimAchievement(ach.key, streamer.id)
    if (result.error) {
      addToast({ icon: '✕', title: 'Claim failed', subtitle: result.error.message, type: 'error' })
      return
    }
    updateAchievement(ach.key, { status: 'claimed' })
    if (result.data.manaGranted > 0) addMana(result.data.manaGranted, 'achievement_claim')
    if (result.data.xpGranted > 0)   addXP(result.data.xpGranted)
    addToast({ icon: ach.icon, title: ach.name, subtitle: ach.rewardDescription, type: 'mana' })
  }

  return (
    <>
      <div className={styles.backdrop} onClick={close} />
      <div className={styles.modal} role="dialog" aria-label="Achievements">
        <div className={styles.header}>
          <span className={styles.title}>Achievements</span>
          <button className={styles.closeBtn} onClick={close}>✕</button>
        </div>
        <div className={styles.body}>
          {SECTIONS.map(({ label, statuses }) => {
            const items = achievements.filter((a) => statuses.includes(a.status))
            if (!items.length) return null
            return (
              <div key={label} className={styles.section}>
                <div className={styles.sectionLabel}>{label}</div>
                {items.map((ach) => (
                  <AchievementRow key={ach.key} ach={ach} onClaim={handleClaim} />
                ))}
              </div>
            )
          })}
        </div>
      </div>
    </>
  )
}

function AchievementRow({ ach, onClaim }) {
  const progressPct = ach.progressRequired > 0
    ? Math.min(100, (ach.progressValue / ach.progressRequired) * 100)
    : 0

  return (
    <div className={clsx(styles.row, styles[`status_${ach.status}`])}>
      <span className={styles.icon}>{ach.icon}</span>
      <div className={styles.info}>
        <div className={styles.achName}>{ach.name}</div>
        <div className={styles.achDesc}>{ach.description}</div>
        {ach.status === 'in_progress' && (
          <div className={styles.progressWrap}>
            <div className={styles.progressTrack}>
              <div className={styles.progressFill} style={{ width: `${progressPct}%` }} />
            </div>
            <span className={styles.progressText}>{ach.progressValue} / {ach.progressRequired}</span>
          </div>
        )}
        <div className={styles.reward}>{ach.rewardDescription}</div>
      </div>
      {ach.status === 'claimable' && (
        <button className={styles.claimBtn} onClick={() => onClaim(ach)}>Claim</button>
      )}
    </div>
  )
}