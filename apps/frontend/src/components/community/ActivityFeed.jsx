import clsx from 'clsx'
import { useStreamerStore } from '../../stores/useStreamerStore'
import styles from './ActivityFeed.module.css'

const EVENT_VERB = {
  asset_purchased: 'acquired',
  asset_activated: 'activated',
  level_up:        'levelled up to',
  achievement:     'claimed',
  listing:         'listed',
}

const EVENT_COLOR = {
  asset_purchased: 'mana',
  asset_activated: 'xp',
  level_up:        'tier',
  achievement:     'gold',
  listing:         'blue',
}

export function ActivityFeed() {
  const feed = useStreamerStore((s) => s.activityFeed)

  return (
    <section className={styles.section}>
      <div className={styles.head}>
        <span className={styles.headLabel}>Live Activity</span>
        <span className={styles.dot} />
      </div>

      <div className={styles.list}>
        {feed.length === 0 && (
          <div className={styles.empty}>Waiting for activity…</div>
        )}
        {feed.map((event) => (
          <ActivityItem key={event.id} event={event} />
        ))}
      </div>
    </section>
  )
}

function ActivityItem({ event }) {
  const colorClass = styles[`event_${EVENT_COLOR[event.eventType] ?? 'default'}`]

  return (
    <div className={clsx(styles.item, colorClass)}>

      {/* Left accent bar colour-coded by event type */}
      <div className={styles.accentBar} />

      <div className={styles.body}>
        {/* Row 1: username + verb */}
        <div className={styles.mainLine}>
          <span className={styles.actor}>{event.displayName}</span>
          <span className={styles.verb}>
            {EVENT_VERB[event.eventType] ?? event.detailText}
          </span>
        </div>

        {/* Row 2: subject (asset name etc) if present */}
        {event.subjectName && (
          <div className={clsx(styles.subject, event.subjectRarity && styles[`rarity_${event.subjectRarity}`])}>
            {event.subjectEmoji && <span className={styles.subjectEmoji}>{event.subjectEmoji}</span>}
            {event.subjectName}
          </div>
        )}
      </div>

      <span className={styles.time}>{event.timeAgo}</span>
    </div>
  )
}