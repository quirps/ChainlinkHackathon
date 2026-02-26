-- =============================================================================
-- ACHIEVEMENTS
-- Achievement definitions are seeded by the platform (not stored per-streamer yet).
-- User progress and claim status are stored in user_achievements.
-- =============================================================================

CREATE TABLE achievement_definitions (
  key             TEXT PRIMARY KEY,      -- e.g. 'first_blood', 'proof_of_humanity'
  name            TEXT NOT NULL,
  description     TEXT NOT NULL,
  icon            TEXT NOT NULL DEFAULT '🏆',
  sort_order      INTEGER NOT NULL DEFAULT 0,

  -- Requirements (evaluated by backend service)
  requirement_type  TEXT NOT NULL,
  -- 'asset_purchase_count', 'watch_time_minutes', 'chat_message_count',
  -- 'level_reached', 'bond_purchased', 'paid_support_cents',
  -- 'stream_milestone_witnessed', 'consecutive_streams', 'human_interaction_count'
  requirement_value INTEGER NOT NULL,   -- the threshold to hit

  -- Reward
  reward_mana       BIGINT NOT NULL DEFAULT 0,
  reward_xp         INTEGER NOT NULL DEFAULT 0,
  reward_asset_id   UUID REFERENCES assets(id),  -- null if no asset reward
  reward_description TEXT,             -- human-readable reward summary

  is_hidden         BOOLEAN NOT NULL DEFAULT FALSE,  -- locked achievements not shown until unlocked
  is_global         BOOLEAN NOT NULL DEFAULT TRUE,   -- false = streamer-specific (future)

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_achievements (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id       UUID REFERENCES streamers(id) ON DELETE CASCADE,
  -- streamer_id null = global achievement, not null = streamer-specific

  achievement_key   TEXT NOT NULL REFERENCES achievement_definitions(key),

  status            achievement_status NOT NULL DEFAULT 'locked',
  progress_value    INTEGER NOT NULL DEFAULT 0,   -- current progress toward requirement_value
  -- e.g. if requirement is 50 human interactions and user has done 32, this is 32

  claimable_at      TIMESTAMPTZ,    -- when status changed to 'claimable'
  claimed_at        TIMESTAMPTZ,

  -- What was actually granted (may differ from definition if config changed)
  mana_granted      BIGINT,
  xp_granted        INTEGER,
  asset_granted_id  UUID REFERENCES user_assets(id),

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(user_id, achievement_key, COALESCE(streamer_id, '00000000-0000-0000-0000-000000000000'::UUID))
);

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id, status);
CREATE INDEX idx_user_achievements_claimable ON user_achievements(user_id) WHERE status = 'claimable';

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

-- =============================================================================
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

-- =============================================================================
-- STRIPE PAYMENTS
-- Records of every Stripe payment intent for credit top-ups.
-- The webhook handler creates/updates these rows.
-- =============================================================================

CREATE TABLE stripe_payments (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  stripe_payment_intent_id TEXT UNIQUE NOT NULL,
  stripe_customer_id      TEXT,
  amount_cents            INTEGER NOT NULL,
  currency                TEXT NOT NULL DEFAULT 'usd',
  status                  TEXT NOT NULL,
  -- 'requires_payment_method', 'requires_confirmation', 'processing',
  -- 'succeeded', 'canceled', 'failed'

  -- Credits granted (only set when status = 'succeeded')
  credits_granted_cents   INTEGER,
  credits_granted_at      TIMESTAMPTZ,

  metadata                JSONB,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_stripe_payments_user ON stripe_payments(user_id, created_at DESC);
CREATE INDEX idx_stripe_payments_intent ON stripe_payments(stripe_payment_intent_id);

-- =============================================================================
-- ACTIVITY FEED EVENTS
-- Denormalized feed of everything that happened in a streamer's community.
-- Written to on every significant event. Read directly for the activity feed
-- on the community page. Avoids expensive JOIN queries for the feed.
-- Retain 7 days rolling (purge via cron).
-- =============================================================================

CREATE TABLE activity_feed_events (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  -- Actor
  user_id         UUID REFERENCES users(id),
  display_name    TEXT NOT NULL,       -- snapshot of username at time of event
  is_anonymous    BOOLEAN NOT NULL DEFAULT FALSE,

  -- Event
  event_type      TEXT NOT NULL,
  -- 'asset_purchased', 'asset_activated', 'bond_purchased', 'listing_created',
  -- 'listing_sold', 'level_up', 'achievement_claimed', 'welcome_drop_claimed'

  -- Display data (pre-rendered for fast feed reads)
  subject_name    TEXT,     -- e.g. asset name, bond quantity
  subject_rarity  asset_rarity,
  subject_emoji   TEXT,
  detail_text     TEXT,     -- e.g. "purchased", "activated", "reached Level 12"

  -- Linked records
  asset_id        UUID REFERENCES assets(id),
  user_asset_id   UUID REFERENCES user_assets(id),
  activation_id   UUID REFERENCES asset_activations(id),

  occurred_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_activity_feed_streamer ON activity_feed_events(streamer_id, occurred_at DESC);
-- Partial index for fast "last 50 events" query
CREATE INDEX idx_activity_feed_recent ON activity_feed_events(streamer_id, occurred_at DESC)
  WHERE occurred_at > NOW() - INTERVAL '7 days';

-- =============================================================================
-- CRE WORKFLOW EXECUTIONS
-- Tracks each Chainlink CRE workflow run for the hackathon requirement.
-- =============================================================================

CREATE TABLE cre_workflow_executions (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  workflow_id       TEXT NOT NULL,     -- Chainlink CRE workflow identifier
  milestone_key     TEXT NOT NULL,     -- e.g. 'followers_10k', 'subscribers_500'
  milestone_value   INTEGER NOT NULL,  -- the threshold that was crossed

  -- External API data snapshot at time of execution
  api_response      JSONB,             -- raw Twitch API response that confirmed milestone
  verified_value    INTEGER,           -- actual value returned (e.g. actual follower count)

  -- Onchain result
  tx_hash           TEXT,              -- CREBridge.onMilestoneVerified() tx
  block_number      BIGINT,

  -- Downstream effects
  loot_drop_triggered BOOLEAN NOT NULL DEFAULT FALSE,
  loot_drop_count     INTEGER,         -- how many users received the drop

  status            TEXT NOT NULL DEFAULT 'pending',
  -- 'pending', 'verified', 'submitted', 'confirmed', 'failed'
  error_message     TEXT,

  initiated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  confirmed_at      TIMESTAMPTZ
);

CREATE INDEX idx_cre_executions_streamer ON cre_workflow_executions(streamer_id, initiated_at DESC);

-- =============================================================================
-- LOOT DROPS
-- When a bond holder milestone is reached (via CRE) or a streamer triggers
-- a manual drop, a loot drop event is created and individual grants are recorded.
-- =============================================================================

CREATE TABLE loot_drops (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  trigger_type    TEXT NOT NULL,
  -- 'cre_milestone', 'manual_streamer', 'bond_holder_special', 'stream_milestone'
  trigger_reference_id UUID,   -- cre_workflow_executions.id or null

  -- What drops
  asset_id        UUID NOT NULL REFERENCES assets(id),
  quantity_per_recipient INTEGER NOT NULL DEFAULT 1,
  total_recipients INTEGER,

  -- Eligibility
  eligible_type   TEXT NOT NULL DEFAULT 'bond_holders',
  -- 'bond_holders', 'all_members', 'level_gated', 'top_n_leaderboard'
  eligible_config JSONB,
  -- For 'level_gated': { "min_level": 5 }
  -- For 'top_n_leaderboard': { "n": 100 }

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE loot_drop_grants (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  loot_drop_id    UUID NOT NULL REFERENCES loot_drops(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_asset_id   UUID REFERENCES user_assets(id),   -- created user_asset row

  granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notified        BOOLEAN NOT NULL DEFAULT FALSE,   -- WebSocket push sent
  notified_at     TIMESTAMPTZ
);

CREATE INDEX idx_loot_drop_grants_drop ON loot_drop_grants(loot_drop_id);
CREATE INDEX idx_loot_drop_grants_user ON loot_drop_grants(user_id, granted_at DESC);

-- =============================================================================
-- SESSIONS / REFRESH TOKENS
-- If using refresh token rotation (recommended).
-- =============================================================================

CREATE TABLE refresh_tokens (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash      TEXT NOT NULL UNIQUE,   -- SHA-256 hash of the actual token
  issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ NOT NULL,
  revoked         BOOLEAN NOT NULL DEFAULT FALSE,
  revoked_at      TIMESTAMPTZ,
  user_agent      TEXT,
  ip_address      INET
);

CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id, expires_at)
  WHERE revoked = FALSE;
CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens(token_hash);

-- =============================================================================
-- TRIGGERS
-- Keep cached balances in sync automatically.
-- =============================================================================

-- Update mana_balance on user_streamer_memberships after every mana_ledger insert
CREATE OR REPLACE FUNCTION sync_mana_balance()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE user_streamer_memberships
  SET mana_balance = NEW.balance_after,
      updated_at = NOW()
  WHERE id = NEW.membership_id;

  -- Also update global_mana_balance on users
  UPDATE users
  SET global_mana_balance = (
    SELECT COALESCE(SUM(mana_balance), 0)
    FROM user_streamer_memberships
    WHERE user_id = NEW.user_id
  ),
  updated_at = NOW()
  WHERE id = NEW.user_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER mana_balance_sync
  AFTER INSERT ON mana_ledger
  FOR EACH ROW EXECUTE FUNCTION sync_mana_balance();

-- Update xp_balance on user_streamer_memberships after every xp_ledger insert
CREATE OR REPLACE FUNCTION sync_xp_balance()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE user_streamer_memberships
  SET xp_balance = NEW.balance_after,
      updated_at = NOW()
  WHERE id = NEW.membership_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER xp_balance_sync
  AFTER INSERT ON xp_ledger
  FOR EACH ROW EXECUTE FUNCTION sync_xp_balance();

-- Update credits balance on users after every credits_ledger insert
CREATE OR REPLACE FUNCTION sync_credits_balance()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE users
  SET global_credits_balance_cents = NEW.balance_after_cents,
      updated_at = NOW()
  WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER credits_balance_sync
  AFTER INSERT ON credits_ledger
  FOR EACH ROW EXECUTE FUNCTION sync_credits_balance();

-- Update updated_at automatically
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER streamers_updated_at BEFORE UPDATE ON streamers FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER assets_updated_at BEFORE UPDATE ON assets FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER bonds_updated_at BEFORE UPDATE ON bonds FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER listings_updated_at BEFORE UPDATE ON listings FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER stripe_payments_updated_at BEFORE UPDATE ON stripe_payments FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER user_achievements_updated_at BEFORE UPDATE ON user_achievements FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================================
-- SEED DATA — ACHIEVEMENT DEFINITIONS
-- =============================================================================

INSERT INTO achievement_definitions (key, name, description, icon, sort_order, requirement_type, requirement_value, reward_mana, reward_xp, reward_description) VALUES
('first_steps',          'First Steps',          'Join a streamer community on MassDX.',                         '🌿', 1,  'membership_created',        1,    100,   50,   '+100 Mana, +50 XP'),
('first_blood',          'First Blood',          'Make your first asset purchase.',                              '🔥', 2,  'asset_purchase_count',      1,    500,   100,  '+500 Mana, +100 XP'),
('voice_of_the_realm',   'Voice of the Realm',   'Send 100 messages in any watched stream.',                     '💬', 3,  'chat_message_count',        100,  300,   200,  '+300 Mana, +200 XP'),
('witness',              'Witness',              'Be present in chat during a stream milestone.',                 '👁',  4,  'stream_milestone_witnessed',1,    300,   150,  '+300 Mana, +150 XP'),
('proof_of_humanity',    'Proof of Humanity',    'Complete 50 unique human interactions (chat, activations, bounties, purchases).', '🤖', 5, 'human_interaction_count', 50, 2000, 500, '+2,000 Mana, +500 XP, exclusive badge'),
('tidal_presence',       'Tidal Presence',       'Be active across 10 consecutive live streams.',                '🌊', 6,  'consecutive_streams',       10,   800,   300,  '+800 Mana, +300 XP'),
('patron_of_the_realm',  'Patron of the Realm',  'Reach $10 total paid support (subscriptions + credits).',      '💎', 7,  'paid_support_cents',        1000, 0,     1000, '+1,000 XP, unique gold border'),
('early_backer',         'Early Backer',         'Purchase a Bond before this streamer reaches 50k followers.',  '🏰', 8,  'bond_purchased_early',      1,    0,     500,  '+500 XP, Founding asset drop'),
('keeper_ascended',      'Keeper Ascended',       'Reach Tier III — Keeper of Embers.',                          '🜂',  9,  'level_reached',             12,   1000,  0,    '+1,000 Mana'),
('archon_ascended',      'Archon Ascended',      'Reach Tier V — Archon''s Veil.',                              '🌀', 10, 'level_reached',             20,   5000,  0,    '+5,000 Mana, Archon exclusive asset');

-- =============================================================================
-- USEFUL VIEWS
-- =============================================================================

-- Fast leaderboard query for a given streamer
CREATE VIEW v_streamer_leaderboard AS
SELECT
  usm.streamer_id,
  usm.user_id,
  u.twitch_display_name,
  u.twitch_avatar_url,
  usm.level,
  usm.tier,
  usm.xp_balance,
  usm.mana_balance,
  RANK() OVER (PARTITION BY usm.streamer_id ORDER BY usm.xp_balance DESC) AS rank
FROM user_streamer_memberships usm
JOIN users u ON u.id = usm.user_id
WHERE u.is_banned = FALSE;

-- User's complete portfolio for a given streamer (inventory + values)
CREATE VIEW v_user_inventory AS
SELECT
  ua.user_id,
  ua.streamer_id,
  ua.id AS user_asset_id,
  a.name,
  a.emoji,
  a.rarity,
  a.asset_type,
  ua.is_consumed,
  ua.is_active,
  ua.is_listed,
  ua.acquired_via,
  ua.acquired_at,
  ua.acquisition_price_mana,
  ua.acquisition_price_cents,
  ua.last_known_floor_mana,
  ua.last_known_floor_cents,
  -- Unrealized gain (mana)
  CASE
    WHEN ua.acquisition_price_mana IS NOT NULL AND ua.last_known_floor_mana IS NOT NULL
    THEN ua.last_known_floor_mana - ua.acquisition_price_mana
    ELSE NULL
  END AS unrealized_gain_mana,
  ua.seller_user_id,
  seller.twitch_display_name AS seller_display_name
FROM user_assets ua
JOIN assets a ON a.id = ua.asset_id
LEFT JOIN users seller ON seller.id = ua.seller_user_id;

-- Bond portfolio summary
CREATE VIEW v_bond_portfolio AS
SELECT
  b.holder_user_id,
  b.streamer_id,
  s.twitch_channel_name AS streamer_name,
  b.quantity,
  b.avg_cost_cents,
  b.current_price_cents,
  b.total_yield_earned_cents,
  (b.quantity * b.current_price_cents) AS current_value_cents,
  (b.quantity * b.current_price_cents) - (b.quantity * b.avg_cost_cents) AS unrealized_pnl_cents,
  b.tranche,
  b.purchased_at
FROM bonds b
JOIN streamers s ON s.id = b.streamer_id;