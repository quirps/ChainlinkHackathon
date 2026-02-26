const API_BASE = import.meta.env.VITE_API_URL ?? 'http://localhost:3000'

async function apiFetch(path, options = {}) {
  const token = localStorage.getItem('massdx_token')
  const headers = {
    'Content-Type': 'application/json',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    ...options.headers,
  }
  try {
    const res = await fetch(`${API_BASE}${path}`, { ...options, headers })
    const json = await res.json()
    if (!res.ok) {
      return { data: null, error: { code: String(res.status), message: json.message ?? 'Request failed' } }
    }
    return { data: json, error: null }
  } catch {
    return { data: null, error: { code: 'NETWORK_ERROR', message: 'Network request failed' } }
  }
}

export const api = {
  // ── Auth / User ────────────────────────────────────────────
  getMe: () =>
    apiFetch('/api/users/me'),

  setWallet: (walletAddress) =>
    apiFetch('/api/users/wallet', {
      method: 'POST',
      body: JSON.stringify({ wallet_address: walletAddress }),
    }),

  claimWelcomeDrop: () =>
    apiFetch('/api/users/me/claim-welcome-drop', { method: 'POST' }),

  // ── Community page (single round-trip for initial load) ────
  // Returns: { streamer, membership, assets, leaderboard,
  //            xpBreakdown, activityFeed, progressionSteps,
  //            userInventory, achievements }
  getCommunityPageData: (channelName) =>
    apiFetch(`/api/community/${channelName}`),

  // ── Assets ────────────────────────────────────────────────
  getAssets: (streamerId, filter = 'mana') =>
    apiFetch(`/api/streamers/${streamerId}/assets?filter=${filter}`),

  purchaseAsset: (assetId, currency) =>
    apiFetch(`/api/assets/${assetId}/purchase`, {
      method: 'POST',
      body: JSON.stringify({ currency }),
    }),

  getInventory: (streamerId) =>
    apiFetch(`/api/streamers/${streamerId}/inventory`),

  // ── Achievements ──────────────────────────────────────────
  claimAchievement: (achievementKey, streamerId) =>
    apiFetch(`/api/achievements/${achievementKey}/claim`, {
      method: 'POST',
      body: JSON.stringify({ streamer_id: streamerId }),
    }),

  // ── Watch session ─────────────────────────────────────────
  startWatchSession: (streamerId) =>
    apiFetch('/api/watch/start', {
      method: 'POST',
      body: JSON.stringify({ streamer_id: streamerId }),
    }),
}