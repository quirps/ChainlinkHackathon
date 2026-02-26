import { useEffect, useRef } from 'react'
import { useDynamicContext } from '@dynamic-labs/sdk-react-core'
import { useUserStore } from '../stores/useUserStore'
import { api } from '../lib/api'

/**
 * AuthProvider sits inside DynamicContextProvider and watches for auth state
 * changes. When Dynamic completes a login it:
 *
 *   1. Extracts the JWT (authToken) and stores it in localStorage so api.js
 *      can attach it to every request automatically.
 *   2. Calls POST /api/users/wallet to register the wallet address with our
 *      backend (creates the user record if first time).
 *   3. Calls GET /api/users/me to get the full user object and puts it in
 *      Zustand so any component can access it.
 *
 * On logout it clears localStorage and resets the Zustand user.
 *
 * This component renders no UI — it's purely a side-effect layer.
 */
export function AuthProvider({ children }) {
  const { authToken, primaryWallet, user: dynamicUser, isAuthenticated } = useDynamicContext()

  const setUser  = useUserStore((s) => s.setUser)
  const logout   = useUserStore((s) => s.logout)
  const storeUser = useUserStore((s) => s.user)

  // Track previous auth state so we only react to transitions
  const wasAuthenticated = useRef(false)

  useEffect(() => {
    const justLoggedIn  = isAuthenticated && !wasAuthenticated.current
    const justLoggedOut = !isAuthenticated && wasAuthenticated.current

    if (justLoggedIn) {
      wasAuthenticated.current = true
      handleLogin(authToken, primaryWallet, dynamicUser)
    }

    if (justLoggedOut) {
      wasAuthenticated.current = false
      handleLogout()
    }
  }, [isAuthenticated, authToken, primaryWallet, dynamicUser])

  // Also rehydrate on page load if Dynamic session is already active
  useEffect(() => {
    if (isAuthenticated && !storeUser) {
      wasAuthenticated.current = true
      handleLogin(authToken, primaryWallet, dynamicUser)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  async function handleLogin(token, wallet, dynUser) {
    if (!token) return

    // 1. Persist JWT for api.js
    localStorage.setItem('massdx_token', token)

    // 2. Register wallet with backend if we have one
    //    (Dynamic creates an embedded AA wallet automatically — it may take
    //     a moment to appear, so we handle the case where it's not ready yet)
    if (wallet?.address) {
      await api.setWallet(wallet.address)
    }

    // 3. Fetch our own user record from the backend
    const result = await api.getMe()
    if (result.data) {
      setUser(result.data)
    } else {
      // Backend returned error — build a minimal user object from Dynamic's
      // data so the UI isn't broken while we debug
      setUser(buildFallbackUser(dynUser, wallet))
    }
  }

  function handleLogout() {
    localStorage.removeItem('massdx_token')
    logout()
  }

  return children
}

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

/**
 * Builds a minimal user object from Dynamic data when the backend isn't
 * available yet (useful during dev before the Rust server is running).
 */
function buildFallbackUser(dynUser, wallet) {
  // Dynamic user has: verifiedCredentials[], email, alias, etc.
  const twitch = dynUser?.verifiedCredentials?.find(
    (c) => c.oauthProvider === 'twitch'
  )

  return {
    id: dynUser?.userId ?? 'unknown',
    twitchUsername:     twitch?.oauthUsername ?? dynUser?.alias ?? 'user',
    twitchDisplayName:  twitch?.oauthDisplayName ?? dynUser?.alias ?? 'User',
    twitchAvatarUrl:    twitch?.oauthAccountPhotos?.[0] ?? null,
    walletAddress:      wallet?.address ?? null,
    globalManaBalance:  0,
    globalCreditBalanceCents: 0,
    welcomeDropClaimed: false,
    isAdmin:            false,
  }
}