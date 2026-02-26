-- =============================================================================
-- MASSDX — COMPLETE DATABASE SCHEMA
-- PostgreSQL 15+ | SQLX compatible
-- =============================================================================
-- DESIGN PRINCIPLES:
--   - All PKs are UUIDs generated server-side (gen_random_uuid())
--   - Mana and XP are APPEND-ONLY ledgers — never update a balance directly.
--     Balances are either cached on the user row (with ledger as source of truth)
--     or computed from the ledger. We cache for read performance.
--   - Monetary amounts (USD) stored as INTEGER cents to avoid float precision.
--   - Timestamps always UTC, always timestamptz.
--   - Soft deletes where data has historical value (listings, assets).
--   - Onchain data (bond wallet addresses, tx hashes) stored alongside
--     offchain mirrors so the backend can serve data without RPC calls.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for username search
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- ENUMS
-- =============================================================================

CREATE TYPE asset_rarity AS ENUM (
  'common',
  'rare',
  'epic',
  'legendary'
);

CREATE TYPE asset_price_type AS ENUM (
  'mana',      -- purchased with social currency
  'credits',   -- purchased with real money (cents)
  'both'       -- can be purchased either way
);

CREATE TYPE mana_source AS ENUM (
  'watch_time',        -- passive watch time grant (5-min heartbeat)
  'chat_activity',     -- message count in window
  'asset_activation',  -- user activated/used an asset
  'bounty_win',        -- participated in winning bounty
  'tip',               -- tipped in custom chat
  'achievement_claim', -- claimed an achievement reward
  'admin_grant',       -- manual grant by streamer/admin
  'purchase_refund'    -- refund on failed purchase
);

CREATE TYPE xp_source AS ENUM (
  'asset_purchase',    -- bought any asset
  'asset_activation',  -- used/consumed an asset
  'watch_time',        -- time-based XP
  'chat_activity',
  'bounty_win',
  'bounty_place',      -- placed a bounty (participation)
  'achievement_claim',
  'bond_purchase',     -- bought a bond in this streamer's community
  'tip',
  'level_bonus'        -- bonus XP granted on level-up (streamer configured)
);

CREATE TYPE achievement_status AS ENUM (
  'locked',      -- requirements not started or hidden
  'in_progress', -- partially completed
  'claimable',   -- completed, reward not yet claimed
  'claimed'      -- reward claimed
);

CREATE TYPE listing_status AS ENUM (
  'active',
  'sold',
  'cancelled',
  'expired'
);

CREATE TYPE bond_tranche AS ENUM (
  'tranche_1', -- earliest, lowest price
  'tranche_2',
  'tranche_3'  -- latest, highest price
);

CREATE TYPE onchain_event_type AS ENUM (
  'bond_minted',
  'bond_transferred',
  'asset_purchased_onchain',
  'milestone_verified',    -- CRE bridge fired
  'loot_drop_triggered',
  'revenue_distributed'
);

CREATE TYPE webhook_source AS ENUM (
  'twitch_eventsub',
  'alchemy',
  'stripe',
  'chainlink_cre'
);

CREATE TYPE streamer_asset_type AS ENUM (
  'curse',
  'omen',
  'verdict',
  'decree',
  'bounty',
  'summon',
  'totem',
  'sound_byte',
  'lore_drop',
  'relic',
  'mood',
  'threat',
  'custom'     -- streamer-defined
);

-- =============================================================================
-- USERS
-- =============================================================================

CREATE TABLE users (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Twitch identity
  twitch_id           TEXT UNIQUE NOT NULL,
  twitch_username     TEXT NOT NULL,
  twitch_display_name TEXT NOT NULL,
  twitch_avatar_url   TEXT,
  twitch_email        TEXT,

  -- Wallet
  wallet_address      TEXT UNIQUE,
  wallet_created_at   TIMESTAMPTZ,

  -- Session
  refresh_token_hash  TEXT,
  last_seen_at        TIMESTAMPTZ,

  -- Global stats
  global_mana_balance BIGINT NOT NULL DEFAULT 0,
  global_credits_balance_cents INTEGER NOT NULL DEFAULT 0,

  -- Flags
  is_admin            BOOLEAN NOT NULL DEFAULT FALSE,
  is_banned           BOOLEAN NOT NULL DEFAULT FALSE,
  welcome_drop_claimed BOOLEAN NOT NULL DEFAULT FALSE,
  anonymous_market    BOOLEAN NOT NULL DEFAULT FALSE,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_twitch_id ON users(twitch_id);
CREATE INDEX idx_users_wallet ON users(wallet_address) WHERE wallet_address IS NOT NULL;
CREATE INDEX idx_users_username_trgm ON users USING GIN (twitch_username gin_trgm_ops);

-- =============================================================================
-- STREAMERS
-- =============================================================================

CREATE TABLE streamers (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Twitch channel info
  twitch_channel_id     TEXT UNIQUE NOT NULL,
  twitch_channel_name   TEXT NOT NULL,
  twitch_game_name      TEXT,
  twitch_follower_count INTEGER NOT NULL DEFAULT 0,
  twitch_subscriber_count INTEGER NOT NULL DEFAULT 0,
  is_live               BOOLEAN NOT NULL DEFAULT FALSE,
  live_viewer_count     INTEGER,
  last_live_at          TIMESTAMPTZ,

  -- Streamer branding
  brand_color           TEXT NOT NULL DEFAULT '#D97B3A',
  status_message        TEXT,
  tier_config           JSONB,
  stream_embed_enabled  BOOLEAN NOT NULL DEFAULT TRUE,

  -- Marketplace config
  marketplace_active    BOOLEAN NOT NULL DEFAULT FALSE,
  bonds_enabled         BOOLEAN NOT NULL DEFAULT FALSE,
  bonds_tranche_1_price_cents INTEGER,
  bonds_tranche_2_price_cents INTEGER,
  bonds_tranche_3_price_cents INTEGER,
  bonds_tranche_1_supply INTEGER NOT NULL DEFAULT 500,
  bonds_tranche_2_supply INTEGER NOT NULL DEFAULT 300,
  bonds_tranche_3_supply INTEGER NOT NULL DEFAULT 200,
  bonds_revenue_share_bps INTEGER NOT NULL DEFAULT 500,

  -- Chainlink CRE
  milestone_follower_threshold INTEGER,
  milestone_last_triggered_at  TIMESTAMPTZ,

  -- Onboarding
  extension_configured  BOOLEAN NOT NULL DEFAULT FALSE,
  eventsub_subscribed   BOOLEAN NOT NULL DEFAULT FALSE,

  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX idx_streamers_user ON streamers(user_id);
CREATE INDEX idx_streamers_live ON streamers(is_live) WHERE is_live = TRUE;

-- =============================================================================
-- USER_STREAMER_MEMBERSHIP
-- =============================================================================

CREATE TABLE user_streamer_memberships (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  -- Level system
  level           INTEGER NOT NULL DEFAULT 1,
  tier            INTEGER NOT NULL DEFAULT 1,
  xp_balance      BIGINT NOT NULL DEFAULT 0,

  -- Mana
  mana_balance    BIGINT NOT NULL DEFAULT 0,

  -- Twitch watch metrics
  watch_time_minutes_total BIGINT NOT NULL DEFAULT 0,
  chat_messages_total      BIGINT NOT NULL DEFAULT 0,
  last_heartbeat_at        TIMESTAMPTZ,

  -- Leaderboard rank
  leaderboard_rank         INTEGER,

  -- Membership timestamps
  first_seen_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(user_id, streamer_id)
);

CREATE INDEX idx_usm_user ON user_streamer_memberships(user_id);
CREATE INDEX idx_usm_streamer ON user_streamer_memberships(streamer_id);
CREATE INDEX idx_usm_leaderboard ON user_streamer_memberships(streamer_id, xp_balance DESC);
CREATE INDEX idx_usm_mana_rank ON user_streamer_memberships(streamer_id, mana_balance DESC);

-- =============================================================================
-- MANA LEDGER
-- =============================================================================

CREATE TABLE mana_ledger (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  membership_id   UUID NOT NULL REFERENCES user_streamer_memberships(id) ON DELETE CASCADE,

  amount          BIGINT NOT NULL,
  source          mana_source NOT NULL,
  description     TEXT,

  asset_id        UUID,
  listing_id      UUID,
  achievement_key TEXT,

  balance_after   BIGINT NOT NULL,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mana_ledger_membership ON mana_ledger(membership_id, created_at DESC);
CREATE INDEX idx_mana_ledger_user_streamer ON mana_ledger(user_id, streamer_id, created_at DESC);
CREATE INDEX idx_mana_ledger_source ON mana_ledger(source, created_at DESC);

-- =============================================================================
-- XP LEDGER
-- =============================================================================

CREATE TABLE xp_ledger (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  membership_id   UUID NOT NULL REFERENCES user_streamer_memberships(id) ON DELETE CASCADE,

  amount          BIGINT NOT NULL,
  source          xp_source NOT NULL,
  description     TEXT,

  asset_id        UUID,
  achievement_key TEXT,
  level_before    INTEGER,
  level_after     INTEGER,

  balance_after   BIGINT NOT NULL,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_xp_ledger_membership ON xp_ledger(membership_id, created_at DESC);
CREATE INDEX idx_xp_ledger_user_streamer ON xp_ledger(user_id, streamer_id, created_at DESC);

-- =============================================================================
-- CREDITS LEDGER
-- =============================================================================

CREATE TABLE credits_ledger (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  amount_cents    INTEGER NOT NULL,
  description     TEXT NOT NULL,

  stripe_payment_intent_id  TEXT,
  stripe_charge_id          TEXT,
  asset_purchase_id         UUID,
  bond_purchase_id          UUID,

  balance_after_cents       INTEGER NOT NULL,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_credits_ledger_user ON credits_ledger(user_id, created_at DESC);

-- =============================================================================
-- ASSETS (TEMPLATE)
-- =============================================================================

CREATE TABLE assets (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  name              TEXT NOT NULL,
  description       TEXT NOT NULL,
  emoji             TEXT NOT NULL DEFAULT '🎁',
  asset_type        streamer_asset_type NOT NULL,
  rarity            asset_rarity NOT NULL DEFAULT 'common',

  price_type        asset_price_type NOT NULL DEFAULT 'mana',
  price_mana        BIGINT,
  price_credits_cents INTEGER,

  xp_on_purchase    INTEGER NOT NULL DEFAULT 0,
  xp_on_activation  INTEGER NOT NULL DEFAULT 0,
  mana_on_activation BIGINT NOT NULL DEFAULT 0,

  supply_type       TEXT NOT NULL DEFAULT 'unlimited',
  supply_max        INTEGER,
  supply_minted     INTEGER NOT NULL DEFAULT 0,

  level_required    INTEGER NOT NULL DEFAULT 1,

  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  is_featured       BOOLEAN NOT NULL DEFAULT FALSE,

  behavior_config   JSONB,

  is_onchain        BOOLEAN NOT NULL DEFAULT FALSE,
  contract_address  TEXT,
  token_id_start    BIGINT,

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_assets_streamer ON assets(streamer_id, is_active);
CREATE INDEX idx_assets_rarity ON assets(streamer_id, rarity);
CREATE INDEX idx_assets_level ON assets(streamer_id, level_required);

-- =============================================================================
-- USER_ASSETS (OWNERSHIP)
-- =============================================================================

CREATE TABLE user_assets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  asset_id        UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,

  acquired_via    TEXT NOT NULL,
  acquired_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  acquisition_price_mana    BIGINT,
  acquisition_price_cents   INTEGER,

  seller_user_id  UUID REFERENCES users(id),

  is_consumed     BOOLEAN NOT NULL DEFAULT FALSE,
  consumed_at     TIMESTAMPTZ,
  is_active       BOOLEAN NOT NULL DEFAULT FALSE,
  activated_at    TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,

  token_id        BIGINT,
  tx_hash         TEXT,

  is_listed       BOOLEAN NOT NULL DEFAULT FALSE,

  last_known_floor_mana     BIGINT,
  last_known_floor_cents    INTEGER,
  value_snapshot_at         TIMESTAMPTZ
);

CREATE INDEX idx_user_assets_user ON user_assets(user_id, streamer_id);
CREATE INDEX idx_user_assets_asset ON user_assets(asset_id);
CREATE INDEX idx_user_assets_active ON user_assets(user_id, is_active) WHERE is_active = TRUE;
CREATE INDEX idx_user_assets_listed ON user_assets(is_listed) WHERE is_listed = TRUE;

-- =============================================================================
-- ASSET ACTIVATIONS
-- =============================================================================

CREATE TABLE asset_activations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_asset_id     UUID NOT NULL REFERENCES user_assets(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  asset_id          UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,

  activated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  target_username   TEXT,
  target_user_id    UUID REFERENCES users(id),

  resolved          BOOLEAN NOT NULL DEFAULT FALSE,
  resolved_at       TIMESTAMPTZ,
  outcome           TEXT,
  outcome_detail    JSONB,

  xp_granted        INTEGER,
  mana_granted      BIGINT,

  pubsub_payload    JSONB,
  pubsub_sent_at    TIMESTAMPTZ
);

CREATE INDEX idx_activations_streamer ON asset_activations(streamer_id, activated_at DESC);
CREATE INDEX idx_activations_user ON asset_activations(user_id, activated_at DESC);

-- =============================================================================
-- SECONDARY MARKET LISTINGS
-- =============================================================================

CREATE TABLE listings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_asset_id   UUID NOT NULL REFERENCES user_assets(id) ON DELETE CASCADE,
  seller_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  asset_id        UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,

  price_mana      BIGINT,
  price_cents     INTEGER,

  status          listing_status NOT NULL DEFAULT 'active',

  buyer_id        UUID REFERENCES users(id),
  sold_at         TIMESTAMPTZ,

  platform_fee_bps INTEGER NOT NULL DEFAULT 500,
  bond_fee_bps     INTEGER NOT NULL DEFAULT 250,

  listed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ,
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_listings_streamer ON listings(streamer_id, status) WHERE status = 'active';
CREATE INDEX idx_listings_asset ON listings(asset_id, status);
CREATE INDEX idx_listings_seller ON listings(seller_id);

-- =============================================================================
-- BONDS
-- =============================================================================

CREATE TABLE bonds (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  holder_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  quantity          INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),

  tranche           bond_tranche NOT NULL DEFAULT 'tranche_1',

  avg_cost_cents    INTEGER NOT NULL,
  current_price_cents INTEGER,

  revenue_share_bps INTEGER NOT NULL,
  total_supply_at_purchase INTEGER NOT NULL,

  total_yield_earned_cents INTEGER NOT NULL DEFAULT 0,
  last_yield_at            TIMESTAMPTZ,

  wallet_address    TEXT NOT NULL,
  contract_address  TEXT,
  onchain_token_id  BIGINT,
  mint_tx_hash      TEXT,

  buyout_eligible   BOOLEAN NOT NULL DEFAULT TRUE,

  purchased_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(streamer_id, holder_user_id)
);

CREATE INDEX idx_bonds_streamer ON bonds(streamer_id);
CREATE INDEX idx_bonds_holder ON bonds(holder_user_id);
CREATE INDEX idx_bonds_wallet ON bonds(wallet_address);

-- =============================================================================
-- BOND YIELD EVENTS
-- =============================================================================

CREATE TABLE bond_yield_events (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  trigger_type      TEXT NOT NULL,
  trigger_reference UUID,

  gross_revenue_cents    INTEGER NOT NULL,
  bond_pool_cents        INTEGER NOT NULL,
  total_bonds_outstanding INTEGER NOT NULL,

  distributed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE bond_yield_payouts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  yield_event_id    UUID NOT NULL REFERENCES bond_yield_events(id) ON DELETE CASCADE,
  bond_id           UUID NOT NULL REFERENCES bonds(id) ON DELETE CASCADE,
  holder_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  bonds_held        INTEGER NOT NULL,
  payout_cents      INTEGER NOT NULL,
  credited_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_yield_events_streamer ON bond_yield_events(streamer_id, distributed_at DESC);
CREATE INDEX idx_yield_payouts_holder ON bond_yield_payouts(holder_user_id, credited_at DESC);


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
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()

);
CREATE UNIQUE INDEX idx_user_achievements_unique ON user_achievements (user_id, achievement_key, COALESCE(streamer_id, '00000000-0000-0000-0000-000000000000'::UUID));
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
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
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
-- =============================================================================

CREATE TABLE onchain_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  event_type      onchain_event_type NOT NULL,
  chain_id        INTEGER NOT NULL DEFAULT 11155111,  -- 11155111 = Sepolia testnet
  contract_address TEXT NOT NULL,
  tx_hash         TEXT NOT NULL,
  block_number    BIGINT NOT NULL,
  log_index       INTEGER NOT NULL,

  -- Decoded event data
  payload         JSONB NOT NULL,

  -- Processing status
  processed       BOOLEAN NOT NULL DEFAULT FALSE,
  processed_at    TIMESTAMPTZ,
  processing_error TEXT,

  -- Alchemy metadata
  alchemy_webhook_id TEXT,
  received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(tx_hash, log_index)
);

CREATE INDEX idx_onchain_unprocessed ON onchain_events(processed, received_at)
  WHERE processed = FALSE;
CREATE INDEX idx_onchain_type ON onchain_events(event_type, received_at DESC);

-- =============================================================================
-- WEBHOOK LOG
-- Raw log of every incoming webhook from every external service.
-- =============================================================================

CREATE TABLE webhook_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source          webhook_source NOT NULL,
  event_type      TEXT NOT NULL,
  raw_payload     JSONB NOT NULL,
  signature_valid BOOLEAN NOT NULL,
  processed       BOOLEAN NOT NULL DEFAULT FALSE,
  processing_error TEXT,
  received_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_webhook_log_source ON webhook_log(source, received_at DESC);
CREATE INDEX idx_webhook_log_unprocessed ON webhook_log(processed, received_at)
  WHERE processed = FALSE;

  -- =============================================================================
-- STRIPE PAYMENTS
-- =============================================================================

CREATE TABLE stripe_payments (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stripe_payment_intent_id TEXT UNIQUE NOT NULL,
  stripe_customer_id       TEXT,
  amount_cents             INTEGER NOT NULL,
  currency                 TEXT NOT NULL DEFAULT 'usd',
  status                   TEXT NOT NULL,
  credits_granted_cents    INTEGER,
  credits_granted_at       TIMESTAMPTZ,
  metadata                 JSONB,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_stripe_payments_user ON stripe_payments(user_id, created_at DESC);
CREATE INDEX idx_stripe_payments_intent ON stripe_payments(stripe_payment_intent_id);

-- =============================================================================
-- ACTIVITY FEED EVENTS
-- =============================================================================

CREATE TABLE activity_feed_events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES users(id),
  display_name    TEXT NOT NULL,
  is_anonymous    BOOLEAN NOT NULL DEFAULT FALSE,
  event_type      TEXT NOT NULL,
  subject_name    TEXT,
  subject_rarity  asset_rarity,
  subject_emoji   TEXT,
  detail_text     TEXT,
  asset_id        UUID REFERENCES assets(id),
  user_asset_id   UUID REFERENCES user_assets(id),
  activation_id   UUID REFERENCES asset_activations(id),
  occurred_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- This index handles "latest events for streamer" perfectly without the partial index
CREATE INDEX idx_activity_feed_streamer ON activity_feed_events(streamer_id, occurred_at DESC);

-- =============================================================================
-- CRE WORKFLOW EXECUTIONS
-- =============================================================================

CREATE TABLE cre_workflow_executions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  streamer_id         UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  workflow_id         TEXT NOT NULL,
  milestone_key       TEXT NOT NULL,
  milestone_value     INTEGER NOT NULL,
  api_response        JSONB,
  verified_value      INTEGER,
  tx_hash             TEXT,
  block_number        BIGINT,
  loot_drop_triggered BOOLEAN NOT NULL DEFAULT FALSE,
  loot_drop_count     INTEGER,
  status              TEXT NOT NULL DEFAULT 'pending',
  error_message       TEXT,
  initiated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  confirmed_at        TIMESTAMPTZ
);

CREATE INDEX idx_cre_executions_streamer ON cre_workflow_executions(streamer_id, initiated_at DESC);

-- =============================================================================
-- LOOT DROPS
-- =============================================================================

CREATE TABLE loot_drops (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  trigger_type    TEXT NOT NULL,
  trigger_reference_id UUID,
  asset_id        UUID NOT NULL REFERENCES assets(id),
  quantity_per_recipient INTEGER NOT NULL DEFAULT 1,
  total_recipients INTEGER,
  eligible_type   TEXT NOT NULL DEFAULT 'bond_holders',
  eligible_config JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE loot_drop_grants (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  loot_drop_id    UUID NOT NULL REFERENCES loot_drops(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_asset_id   UUID REFERENCES user_assets(id),
  granted_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notified        BOOLEAN NOT NULL DEFAULT FALSE,
  notified_at     TIMESTAMPTZ
);

CREATE INDEX idx_loot_drop_grants_drop ON loot_drop_grants(loot_drop_id);
CREATE INDEX idx_loot_drop_grants_user ON loot_drop_grants(user_id, granted_at DESC);

-- =============================================================================
-- SESSIONS / REFRESH TOKENS
-- =============================================================================

CREATE TABLE refresh_tokens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash      TEXT NOT NULL UNIQUE,
  issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ NOT NULL,
  revoked         BOOLEAN NOT NULL DEFAULT FALSE,
  revoked_at      TIMESTAMPTZ,
  user_agent      TEXT,
  ip_address      INET
);

-- FIX: Changed 'revoked = FALSE' to 'NOT revoked' for immutability
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens(user_id, expires_at)
  WHERE NOT revoked;

CREATE INDEX idx_refresh_tokens_hash ON refresh_tokens(token_hash);

-- =============================================================================
-- TRIGGERS
-- =============================================================================

CREATE OR REPLACE FUNCTION sync_mana_balance()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE user_streamer_memberships
  SET mana_balance = NEW.balance_after,
      updated_at = NOW()
  WHERE id = NEW.membership_id;

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