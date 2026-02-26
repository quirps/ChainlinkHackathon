import { create } from 'zustand'
import { immer } from 'zustand/middleware/immer'

const SOURCE_LABELS = {
  watch_time:        'Watch time',
  chat_activity:     'Chat activity',
  asset_activation:  'Activations',
  bounty_win:        'Bounty wins',
  tip:               'Tips',
  achievement_claim: 'Achievements',
  admin_grant:       'Bonus',
}

export const useUserStore = create(
  immer((set) => ({
    user: null,
    isAuthenticated: false,
    isLoading: true,
    membership: null,
    sessionManaGained: 0,
    sessionManaBreakdown: [], // [{ source, label, amount, percentOfTotal }]

    setUser: (user) => set((s) => {
      s.user = user
      s.isAuthenticated = true
      s.isLoading = false
    }),

    setMembership: (membership) => set((s) => {
      s.membership = membership
    }),

    // Called on every WebSocket mana_grant event.
    // Updates cached balance + session breakdown in one mutation.
    addMana: (amount, source) => set((s) => {
      if (!s.user) return
      s.user.globalManaBalance += amount
      s.sessionManaGained += amount
      if (s.membership) s.membership.manaBalance += amount

      const label = SOURCE_LABELS[source] ?? source
      const existing = s.sessionManaBreakdown.find((b) => b.source === source)
      if (existing) {
        existing.amount += amount
      } else {
        s.sessionManaBreakdown.push({ source, label, amount, percentOfTotal: 0 })
      }

      const total = s.sessionManaBreakdown.reduce((acc, b) => acc + b.amount, 0)
      s.sessionManaBreakdown.forEach((b) => {
        b.percentOfTotal = total > 0 ? (b.amount / total) * 100 : 0
      })
    }),

    addXP: (amount) => set((s) => {
      if (!s.membership) return
      s.membership.xpBalance += amount
      const remaining = s.membership.nextLevelXp - s.membership.xpBalance
      s.membership.xpToNextLevel = Math.max(0, remaining)
    }),

    setLevel: (level, tier, tierName, tierGlyph) => set((s) => {
      if (!s.membership) return
      s.membership.level = level
      s.membership.tier = tier
      s.membership.tierName = tierName
      s.membership.tierGlyph = tierGlyph
    }),

    deductMana: (amount) => set((s) => {
      if (!s.user) return
      s.user.globalManaBalance -= amount
      if (s.membership) s.membership.manaBalance -= amount
    }),

    logout: () => set((s) => {
      s.user = null
      s.isAuthenticated = false
      s.membership = null
      s.sessionManaGained = 0
      s.sessionManaBreakdown = []
    }),
  }))
)