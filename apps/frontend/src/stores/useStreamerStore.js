import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

export const useStreamerStore = create(
  immer((set) => ({
    streamer: null,
    assets: [],
    userInventory: [],
    leaderboard: [],
    xpBreakdown: [],
    activityFeed: [],
    progressionSteps: [],
    achievements: [],
    isLoading: false,
    error: null,

    setStreamer:          (v) => set((s) => { s.streamer = v }),
    setAssets:            (v) => set((s) => { s.assets = v }),
    setInventory:         (v) => set((s) => { s.userInventory = v }),
    setLeaderboard:       (v) => set((s) => { s.leaderboard = v }),
    setXPBreakdown:       (v) => set((s) => { s.xpBreakdown = v }),
    setActivityFeed:      (v) => set((s) => { s.activityFeed = v }),
    setProgressionSteps:  (v) => set((s) => { s.progressionSteps = v }),
    setAchievements:      (v) => set((s) => { s.achievements = v }),
    setLoading:           (v) => set((s) => { s.isLoading = v }),
    setError:             (v) => set((s) => { s.error = v }),

    prependActivityEvent: (event) => set((s) => {
      s.activityFeed.unshift(event)
      if (s.activityFeed.length > 50) s.activityFeed = s.activityFeed.slice(0, 50)
    }),

    updateAchievement: (key, updates) => set((s) => {
      const idx = s.achievements.findIndex((a) => a.key === key)
      if (idx !== -1) Object.assign(s.achievements[idx], updates)
    }),

    setLiveStatus: (isLive, viewerCount) => set((s) => {
      if (s.streamer) {
        s.streamer.isLive = isLive
        s.streamer.liveViewerCount = viewerCount
      }
    }),

    // Optimistic: add purchased asset immediately before server confirms
    addUserAsset: (asset) => set((s) => {
      s.userInventory.unshift(asset)
    }),
  }))
)