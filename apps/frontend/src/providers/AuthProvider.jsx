import { useEffect, useRef } from 'react'
import { useDynamicContext } from '@dynamic-labs/sdk-react-core'
import { useUserStore } from '../stores/useUserStore'
import { api } from '../lib/api'

export function AuthProvider({ children }) {
  // !! dynamicUser is the correct Dynamic auth check — isAuthenticated is undefined
  const { authToken, primaryWallet, user: dynamicUser } = useDynamicContext()
  const isLoggedIn = !!dynamicUser

  const setUser   = useUserStore((s) => s.setUser)
  const logout    = useUserStore((s) => s.logout)
  const storeUser = useUserStore((s) => s.user)

  const wasLoggedIn = useRef(false)

  // React to login/logout transitions
  useEffect(() => {
    const justLoggedIn  = isLoggedIn && !wasLoggedIn.current
    const justLoggedOut = !isLoggedIn && wasLoggedIn.current

    if (justLoggedIn) {
      wasLoggedIn.current = true
      handleLogin(authToken, primaryWallet, dynamicUser)
    }

    if (justLoggedOut) {
      wasLoggedIn.current = false
      handleLogout()
    }
  }, [isLoggedIn, authToken, primaryWallet, dynamicUser])

  // Rehydrate on page load when Dynamic session is already active
  useEffect(() => {
    if (isLoggedIn && !storeUser) {
      wasLoggedIn.current = true
      handleLogin(authToken, primaryWallet, dynamicUser)
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  async function handleLogin(token, wallet, dynUser) {
    // While backend isn't live, build from Dynamic data directly
    // Once backend is up: store token, call /api/users/wallet, then /api/users/me
    if (token) localStorage.setItem('massdx_token', token)

    if (wallet?.address) {
      await api.setWallet(wallet.address)
    }

    const result = await api.getMe()
    if (result.data) {
      setUser(result.data)
    } else {
      // Backend not available — build from Dynamic's verifiedCredentials
      setUser(buildFallbackUser(dynUser, wallet))
    }
  }

  function handleLogout() {
    localStorage.removeItem('massdx_token')
    logout()
  }

  return children
}

function buildFallbackUser(dynUser, wallet) {
  // Find the Twitch credential in verifiedCredentials array
  // Shape from Dynamic: { oauthProvider: 'twitch', oauthUsername, oauthDisplayName, oauthAccountPhotos: [] }
  const twitch = dynUser?.verifiedCredentials?.find(
    (c) => c.oauthProvider === 'twitch'
  )

  return {
    id:                       dynUser?.userId ?? 'unknown',
    twitchUsername:           twitch?.oauthUsername ?? dynUser?.alias ?? 'user',
    twitchDisplayName:        twitch?.oauthDisplayName ?? twitch?.oauthUsername ?? dynUser?.alias ?? 'User',
    twitchAvatarUrl:          twitch?.oauthAccountPhotos?.[0] ?? null,
    walletAddress:            wallet?.address ?? null,
    globalManaBalance:        0,
    globalCreditBalanceCents: 0,
    welcomeDropClaimed:       false,
    isAdmin:                  false,
  }
}