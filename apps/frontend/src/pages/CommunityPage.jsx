import { useEffect } from 'react'
import { useParams } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { useDynamicContext } from '@dynamic-labs/sdk-react-core'
import { Chrome } from '../components/chrome/Chrome'
import { IdentityColumn } from '../components/community/IdentityColumn'
import { MainColumn } from '../components/community/MainColumn'
import { RightColumn } from '../components/community/RightColumn'
import { AchievementsModal } from '../components/modals/AchievementsModal'
import { CommunityAuthModal } from '../components/auth/CommunityAuthModal'
import { useWebSocket } from '../hooks/useWebSocket'
import { useStreamerStore } from '../stores/useStreamerStore'
import { useUserStore } from '../stores/useUserStore'
import { useUIStore } from '../stores/useUIStore'
import { api } from '../lib/api'
import { MOCK_PAGE_DATA } from '../lib/mockData'
import styles from './CommunityPage.module.css'

const USE_MOCK = true

export function CommunityPage() {
  const { channelName = 'nightowltv' } = useParams()

  // ── Store wiring ───────────────────────────────────────────
  const setStreamer          = useStreamerStore((s) => s.setStreamer)
  const setAssets            = useStreamerStore((s) => s.setAssets)
  const setInventory         = useStreamerStore((s) => s.setInventory)
  const setLeaderboard       = useStreamerStore((s) => s.setLeaderboard)
  const setXPBreakdown       = useStreamerStore((s) => s.setXPBreakdown)
  const setActivityFeed      = useStreamerStore((s) => s.setActivityFeed)
  const setProgressionSteps  = useStreamerStore((s) => s.setProgressionSteps)
  const setAchievements      = useStreamerStore((s) => s.setAchievements)
  const streamerId           = useStreamerStore((s) => s.streamer?.id ?? null)
  const brandColor           = useStreamerStore((s) => s.streamer?.brandColor ?? '#D97B3A')

  const setMembership        = useUserStore((s) => s.setMembership)
  const user                 = useUserStore((s) => s.user)

  const openWelcomeDrop      = useUIStore((s) => s.openWelcomeDropModal)
  const communityAuthOpen    = useUIStore((s) => s.communityAuthModalOpen)
  const closeCommunityAuth   = useUIStore((s) => s.closeCommunityAuthModal)

  // Auto-close auth modal when Dynamic completes login
  const { isAuthenticated } = useDynamicContext()
  useEffect(() => {
    if (isAuthenticated && communityAuthOpen) {
      closeCommunityAuth()
    }
  }, [isAuthenticated, communityAuthOpen, closeCommunityAuth])

  // ── Data loading ───────────────────────────────────────────
  const { data, isError } = useQuery({
    queryKey: ['communityPage', channelName],
    queryFn: () => USE_MOCK
      ? Promise.resolve({ data: MOCK_PAGE_DATA, error: null })
      : api.getCommunityPageData(channelName),
    staleTime: 60_000,
  })

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

  // ── WebSocket (fires once streamerId is known) ─────────────
  useWebSocket(streamerId)

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

      {/* Modals */}
      <AchievementsModal />
      {communityAuthOpen && (
        <CommunityAuthModal
          streamerName={channelName}
          onClose={closeCommunityAuth}
        />
      )}
    </div>
  )
}