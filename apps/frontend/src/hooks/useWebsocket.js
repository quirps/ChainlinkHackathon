import { useEffect, useRef, useCallback } from 'react'
import { useUserStore } from '../stores/useUserStore'
import { useStreamerStore } from '../stores/useStreamerStore'
import { useUIStore } from '../stores/useUIStore'

const WS_URL = import.meta.env.VITE_WS_URL ?? 'ws://localhost:3000/ws'
const RECONNECT_DELAY_MS = 3000
const MAX_RECONNECT_ATTEMPTS = 8

export function useWebSocket(streamerId) {
  const wsRef = useRef(null)
  const reconnectAttempts = useRef(0)
  const reconnectTimer = useRef(null)
  const intentionalClose = useRef(false)

  const addMana            = useUserStore((s) => s.addMana)
  const addXP              = useUserStore((s) => s.addXP)
  const setLevel           = useUserStore((s) => s.setLevel)
  const prependActivity    = useStreamerStore((s) => s.prependActivityEvent)
  const addToast           = useUIStore((s) => s.addToast)
  const openLevelUpModal   = useUIStore((s) => s.openLevelUpModal)

  const handleMessage = useCallback((raw) => {
    let event
    try { event = JSON.parse(raw) } catch { return }

    switch (event.type) {
      case 'mana_grant':
        addMana(event.payload.amount, event.payload.source)
        addToast({ icon: '✦', title: `+${event.payload.amount.toLocaleString()} Mana`, subtitle: event.payload.description, type: 'mana' })
        break

      case 'xp_grant':
        addXP(event.payload.amount)
        addToast({ icon: '⚡', title: `+${event.payload.amount} XP`, subtitle: event.payload.description ?? '', type: 'xp' })
        break

      case 'level_up':
        setLevel(event.payload.levelAfter, event.payload.tierAfter, event.payload.tierName, '')
        openLevelUpModal({ levelBefore: event.payload.levelBefore, levelAfter: event.payload.levelAfter, tierName: event.payload.tierName })
        break

      case 'activity_event':
        prependActivity(event.payload)
        break

      case 'achievement_claimable':
        addToast({ icon: '🏆', title: 'Achievement ready', subtitle: event.payload.achievementName ?? 'Check your achievements', type: 'info' })
        break

      case 'loot_drop':
        addToast({ icon: '🎁', title: 'Loot drop!', subtitle: `You received: ${event.payload.assetName}`, type: 'info' })
        break

      default:
        break
    }
  }, [addMana, addXP, setLevel, prependActivity, addToast, openLevelUpModal])

  const connect = useCallback(() => {
    if (!streamerId) return
    if (wsRef.current?.readyState === WebSocket.OPEN) return

    const token = localStorage.getItem('massdx_token')
    const url = `${WS_URL}?streamer=${streamerId}${token ? `&token=${token}` : ''}`

    const ws = new WebSocket(url)
    wsRef.current = ws

    ws.onopen = () => { reconnectAttempts.current = 0 }
    ws.onmessage = (e) => handleMessage(e.data)
    ws.onclose = () => {
      if (intentionalClose.current) return
      if (reconnectAttempts.current < MAX_RECONNECT_ATTEMPTS) {
        const delay = RECONNECT_DELAY_MS * Math.min(reconnectAttempts.current + 1, 4)
        reconnectAttempts.current++
        reconnectTimer.current = setTimeout(connect, delay)
      }
    }
  }, [streamerId, handleMessage])

  useEffect(() => {
    intentionalClose.current = false
    connect()
    return () => {
      intentionalClose.current = true
      if (reconnectTimer.current) clearTimeout(reconnectTimer.current)
      wsRef.current?.close()
    }
  }, [connect])

  // Heartbeat every 5 min — backend uses this to log watch time
  useEffect(() => {
    if (!streamerId) return
    const interval = setInterval(() => {
      if (wsRef.current?.readyState === WebSocket.OPEN) {
        wsRef.current.send(JSON.stringify({ type: 'heartbeat', streamerId }))
      }
    }, 5 * 60 * 1000)
    return () => clearInterval(interval)
  }, [streamerId])
}