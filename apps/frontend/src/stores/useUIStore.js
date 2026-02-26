import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

export const useUIStore = create(
  immer((set) => ({
    activeTab: 'market',        // 'market' | 'inventory'
    marketFilter: 'mana',       // 'mana' | 'credits' | 'all'

    // Modals
    achievementsModalOpen: false,
    levelUpModalOpen: false,
    welcomeDropModalOpen: false,
    communityAuthModalOpen: false,   // Twitch-only — community pages
    web3AuthModalOpen: false,        // Full wallet+social — trader/market pages
    levelUpData: null,               // { levelBefore, levelAfter, tierName }

    toasts: [],                 // [{ id, icon, title, subtitle, type }]

    setActiveTab:    (tab)    => set((s) => { s.activeTab = tab }),
    setMarketFilter: (filter) => set((s) => { s.marketFilter = filter }),

    openAchievementsModal:  () => set((s) => { s.achievementsModalOpen = true }),
    closeAchievementsModal: () => set((s) => { s.achievementsModalOpen = false }),

    openLevelUpModal: (data) => set((s) => {
      s.levelUpData = data
      s.levelUpModalOpen = true
    }),
    closeLevelUpModal: () => set((s) => {
      s.levelUpModalOpen = false
      s.levelUpData = null
    }),

    openWelcomeDropModal:  () => set((s) => { s.welcomeDropModalOpen = true }),
    closeWelcomeDropModal: () => set((s) => { s.welcomeDropModalOpen = false }),

    openCommunityAuthModal: () => set((s) => { s.communityAuthModalOpen = true }),
    closeCommunityAuthModal: () => set((s) => { s.communityAuthModalOpen = false }),

    openWeb3AuthModal: () => set((s) => { s.web3AuthModalOpen = true }),
    closeWeb3AuthModal: () => set((s) => { s.web3AuthModalOpen = false }),

    addToast: (toast) => set((s) => {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`
      s.toasts.push({ ...toast, id })
      setTimeout(() => {
        set((inner) => { inner.toasts = inner.toasts.filter((t) => t.id !== id) })
      }, 3400)
    }),

    removeToast: (id) => set((s) => {
      s.toasts = s.toasts.filter((t) => t.id !== id)
    }),
  }))
)