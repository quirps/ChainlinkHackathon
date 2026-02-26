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
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

);
CREATE UNIQUE INDEX idx_user_achievements_unique ON user_achievements (user_id, achievement_key, COALESCE(streamer_id, '00000000-0000-0000-0000-000000000000'::UUID));
CREATE INDEX idx_user_achievements_user ON user_achievements(user_id, status);
CREATE INDEX idx_user_achievements_claimable ON user_achievements(user_id) WHERE status = 'claimable';
