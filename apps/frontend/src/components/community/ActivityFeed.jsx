import clsx from 'clsx'
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './ActivityFeed.module.css'

export function ActivityFeed() {
  const feed = useStreamerStore((s) => s.activityFeed)

  return (
    <section className={styles.section}>
      <div className={styles.head}>
        <span>Live Activity</span>
        <span className={styles.dot} />
      </div>
      <div className={styles.list}>
        {feed.length === 0 && (
          <div className={styles.empty}>Waiting for activity…</div>
        )}
        {feed.map((event) => (
          <div key={event.id} className={styles.item}>
            <span className={styles.avi}>{event.avatarEmoji}</span>
            <div className={styles.body}>
              <span className={styles.actor}>{event.displayName}</span>
              {' '}
              <span className={styles.verb}>{event.detailText}</span>
              {event.subjectName && (
                <>
                  {' '}
                  <span className={clsx(styles.subject, event.subjectRarity && styles[`rarity_${event.subjectRarity}`])}>
                    {event.subjectEmoji} {event.subjectName}
                  </span>
                </>
              )}
            </div>
            <span className={styles.time}>{event.timeAgo}</span>
          </div>
        ))}
      </div>
    </section>
  )
}