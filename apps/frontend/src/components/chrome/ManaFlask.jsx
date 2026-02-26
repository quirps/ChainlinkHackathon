import { useUserStore } from '../../stores/useUserStore'
import styles from './ManaFlask.module.css'

export function ManaFlask() {
  const balance = useUserStore((s) => s.user?.globalManaBalance ?? 0)

  return (
    <div className={styles.pill} title="Your Mana balance">
      <svg className={styles.flask} viewBox="0 0 16 20" fill="none" aria-hidden="true">
        <defs>
          <linearGradient id="manaFill" x1="0" y1="1" x2="0" y2="0">
            <stop offset="0%"   stopColor="#1A6ECC" />
            <stop offset="60%"  stopColor="#3AABF5" />
            <stop offset="100%" stopColor="#7DD8FF" />
          </linearGradient>
          <linearGradient id="manaGlass" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%"   stopColor="rgba(255,255,255,0.15)" />
            <stop offset="100%" stopColor="rgba(255,255,255,0.03)" />
          </linearGradient>
          <clipPath id="flask-clip">
            <path d="M4.5 6L1 15a2 2 0 0 0 1.8 2.8h10.4A2 2 0 0 0 15 15L11.5 6z" />
          </clipPath>
        </defs>
        <path
          d="M5 1h6M4.5 1v5L1 15a2 2 0 0 0 1.8 2.8h10.4A2 2 0 0 0 15 15L11.5 6V1"
          stroke="rgba(125,216,255,0.35)" strokeWidth="1" strokeLinecap="round"
        />
        <rect x="0" y="8" width="16" height="12" fill="url(#manaFill)" clipPath="url(#flask-clip)" opacity="0.85" />
        <rect x="0" y="8" width="16" height="12" fill="url(#manaGlass)" clipPath="url(#flask-clip)" />
        <circle cx="5" cy="15" r="0.8" fill="rgba(125,216,255,0.6)" clipPath="url(#flask-clip)" />
        <circle cx="9" cy="12" r="0.5" fill="rgba(125,216,255,0.4)" clipPath="url(#flask-clip)" />
      </svg>
      <div>
        <div className={styles.amount}>{balance.toLocaleString()}</div>
        <div className={styles.label}>Mana</div>
      </div>
    </div>
  )
}