- =============================================================================
-- CHAT METRIC SNAPSHOTS
-- The chatbot reports per-user message counts in 5-minute windows.
-- We store these for mana grants and analytics.
-- =============================================================================

CREATE TABLE chat_metric_snapshots (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  -- Can be null if message came from a non-linked user
  user_id         UUID REFERENCES users(id),
  twitch_username TEXT NOT NULL,

  window_start    TIMESTAMPTZ NOT NULL,
  window_end      TIMESTAMPTZ NOT NULL,
  message_count   INTEGER NOT NULL DEFAULT 0,

  -- Mana granted for this window (0 if user not linked or below threshold)
  mana_granted    BIGINT NOT NULL DEFAULT 0,
  threshold_met   BOOLEAN NOT NULL DEFAULT FALSE,
  -- threshold: 5+ messages in window = active chatter = mana grant

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_chat_metrics_streamer ON chat_metric_snapshots(streamer_id, window_start DESC);
CREATE INDEX idx_chat_metrics_user ON chat_metric_snapshots(user_id, window_start DESC)
  WHERE user_id IS NOT NULL;

-- =============================================================================
-- ONCHAIN EVENTS
-- Mirror of all blockchain events relevant to MassDX.
-- Populated by the Alchemy webhook handler.
-- Source of truth for anything onchain — we never trust frontend for this.
-- =============================================================================

CREATE TABLE onchain_events (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  event_type      onchain_event_type NOT NULL,
  chain_id        INTEGER NOT NULL DEFAULT 11155111,  -- 11155111 = Sepolia testnet
  contract_address TEXT NOT NULL,
  tx_hash         TEXT NOT NULL,
  block_number    BIGINT NOT NULL,
  log_index       INTEGER NOT NULL,

  -- Decoded event data
  payload         JSONB NOT NULL,
  -- bond_minted:       { "streamer_id": "...", "holder": "0x...", "quantity": 5, "tranche": 1 }
  -- milestone_verified: { "streamer_id": "...", "milestone_key": "followers_10k" }
  -- revenue_distributed: { "streamer_id": "...", "amount_wei": "..." }

  -- Processing status
  processed       BOOLEAN NOT NULL DEFAULT FALSE,
  processed_at    TIMESTAMPTZ,
  processing_error TEXT,    -- if processing failed, why

  -- Alchemy metadata
  alchemy_webhook_id TEXT,
  received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(tx_hash, log_index)  -- prevent duplicate processing
);

CREATE INDEX idx_onchain_unprocessed ON onchain_events(processed, received_at)
  WHERE processed = FALSE;
CREATE INDEX idx_onchain_type ON onchain_events(event_type, received_at DESC);

-- =============================================================================
-- WEBHOOK LOG
-- Raw log of every incoming webhook from every external service.
-- Kept for debugging and replay. Separate from processed business events.
-- =============================================================================

CREATE TABLE webhook_log (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source          webhook_source NOT NULL,
  event_type      TEXT NOT NULL,    -- e.g. 'channel.subscribe', 'checkout.session.completed'
  raw_payload     JSONB NOT NULL,
  signature_valid BOOLEAN NOT NULL,
  processed       BOOLEAN NOT NULL DEFAULT FALSE,
  processing_error TEXT,
  received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_log_source ON webhook_log(source, received_at DESC);
CREATE INDEX idx_webhook_log_unprocessed ON webhook_log(processed, received_at)
  WHERE processed = FALSE;
-- Retain webhook_log for 30 days then archive/delete (handle via pg_partman or cron job)

