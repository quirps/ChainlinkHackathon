

-- =============================================================================
-- TWITCH WATCH SESSIONS
-- Tracks active watch sessions for mana grant calculation.
-- A session starts when the user loads the streamer page while stream is live.
-- Heartbeats arrive every 5 minutes from the frontend.
-- Session ends when heartbeat stops arriving (timeout: 8 minutes).
-- =============================================================================

CREATE TABLE watch_sessions (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  membership_id   UUID NOT NULL REFERENCES user_streamer_memberships(id),

  started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at        TIMESTAMPTZ,               -- null = session still active or not yet closed
  last_heartbeat  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Source of the session
  source          TEXT NOT NULL DEFAULT 'web',
  -- 'web' = MassDX page, 'extension' = Twitch Extension panel
  -- 'twitch_direct' = user is on twitch.tv (reported via extension)

  -- Mana granted this session
  heartbeat_count INTEGER NOT NULL DEFAULT 0,   -- each heartbeat = one 5-min window
  mana_granted    BIGINT NOT NULL DEFAULT 0,
  xp_granted      INTEGER NOT NULL DEFAULT 0,

  -- Bonus multiplier (e.g. 1.1 if watching on Twitch directly)
  mana_multiplier NUMERIC(4,2) NOT NULL DEFAULT 1.00
);

CREATE INDEX idx_watch_sessions_active ON watch_sessions(user_id, streamer_id)
  WHERE ended_at IS NULL;
CREATE INDEX idx_watch_sessions_heartbeat ON watch_sessions(last_heartbeat)
  WHERE ended_at IS NULL;
-- Background job queries this index to find stale sessions (last_heartbeat > 8 min ago)
-- and closes them.

