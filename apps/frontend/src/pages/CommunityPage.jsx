import { useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Chrome } from '../components/chrome/Chrome'
import { IdentityColumn } from '../components/community/IdentityColumn'
import { MainColumn } from '../components/community/MainColumn'
import { RightColumn } from '../components/community/RightColumn'
import { AchievementsModal } from '../components/modals/AchievementsModal'
import { useWebSocket } from '../hooks/useWebSocket'
import { useStreamerStore } from '../stores/useStreamerStore'
import { useUserStore } from '../stores/useUserStore'
import { useUIStore } from '../stores/useUIStore'
import { api } from '../lib/api'
import { MOCK_PAGE_DATA } from '../lib/mockData'
import styles from './CommunityPage.module.css'

// Swap this flag to false once the backend is live
const USE_MOCK = true

export function CommunityPage() {
  const { channelName = 'nightowltv' } = useParams()

  const setStreamer         = useStreamerStore((s) => s.setStreamer)
  const setAssets          = useStreamerStore((s) => s.setAssets)
  const setInventory       = useStreamerStore((s) => s.setInventory)
  const setLeaderboard     = useStreamerStore((s) => s.setLeaderboard)
  const setXPBreakdown     = useStreamerStore((s) => s.setXPBreakdown)
  const setActivityFeed    = useStreamerStore((s) => s.setActivityFeed)
  const setProgressionSteps = useStreamerStore((s) => s.setProgressionSteps)
  const setAchievements    = useStreamerStore((s) => s.setAchievements)
  const streamerId         = useStreamerStore((s) => s.streamer?.id ?? null)

  const setMembership      = useUserStore((s) => s.setMembership)
  const user               = useUserStore((s) => s.user)
  const openWelcomeDrop    = useUIStore((s) => s.openWelcomeDropModal)

  // React Query handles loading/error state and caching
  const { data, isError } = useQuery({
    queryKey: ['communityPage', channelName],
    queryFn: () => USE_MOCK
      ? Promise.resolve({ data: MOCK_PAGE_DATA, error: null })
      : api.getCommunityPageData(channelName),
    staleTime: 60_000,
  })

  // Hydrate stores once data arrives
  useEffect(() => {
    if (!data?.data) return
    const d = data.data
    setStreamer(d.streamer)
    setAssets(d.assets)
    setLeaderboard(d.leaderboard)
    setXPBreakdown(d.xpBreakdown)
    setActivityFeed(d.activityFeed)
    setProgressionSteps(d.progressionSteps)
    setAchievements(d.achievements)
    if (d.membership)    setMembership(d.membership)
    if (d.userInventory) setInventory(d.userInventory)
    if (user && !user.welcomeDropClaimed) setTimeout(openWelcomeDrop, 1200)
  }, [data]) // eslint-disable-line react-hooks/exhaustive-deps

  // Connect WebSocket once we have a streamer ID
  useWebSocket(streamerId)

  const brandColor = useStreamerStore((s) => s.streamer?.brandColor ?? '#D97B3A')

  if (isError) {
    return (
      <div className={styles.errorState}>
        <p>Could not load this page. Try refreshing.</p>
      </div>
    )
  }

  return (
    <div className={styles.page}>
      <div className={styles.amb} style={{ '--brand': brandColor }} />

      <Chrome streamerChannelName={channelName} />

      <div className={styles.layout}>
        <IdentityColumn />
        <MainColumn />
        <RightColumn />
      </div>

      <AchievementsModal />
    </div>
  )
}