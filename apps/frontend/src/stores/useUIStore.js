import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

export const useUIStore = create(
  immer((set) => ({
    activeTab: 'market',        // 'market' | 'inventory'
    marketFilter: 'mana',       // 'mana' | 'credits' | 'all'

    achievementsModalOpen: false,
    levelUpModalOpen: false,
    welcomeDropModalOpen: false,
    levelUpData: null,          // { levelBefore, levelAfter, tierName }

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

    addToast: (toast) => set((s) => {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2, 7)}`
      s.toasts.push({ ...toast, id })
      // Belt-and-suspenders cleanup after 3.4s (component also handles its own removal)
      setTimeout(() => {
        set((inner) => { inner.toasts = inner.toasts.filter((t) => t.id !== id) })
      }, 3400)
    }),

    removeToast: (id) => set((s) => {
      s.toasts = s.toasts.filter((t) => t.id !== id)
    }),
  }))
)