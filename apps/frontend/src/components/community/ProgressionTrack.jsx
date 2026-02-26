import clsx from 'clsx'
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './ProgressionTrack.module.css'

export function ProgressionTrack() {
  const steps = useStreamerStore((s) => s.progressionSteps)
  if (!steps.length) return null

  return (
    <div className={styles.zone}>
      <div className={styles.label}>Progression Path</div>
      <div className={styles.list}>
        {steps.map((step) => (
          <div key={step.level} className={clsx(styles.row, styles[`status_${step.status}`])}>
            <span className={styles.icon}>{step.icon}</span>
            <div className={styles.info}>
              <div className={styles.name}>{step.name}</div>
              <div className={styles.detail}>{step.detail}</div>
            </div>
            <div className={styles.level}>Lv {step.level}</div>
          </div>
        ))}
      </div>
    </div>
  )
}