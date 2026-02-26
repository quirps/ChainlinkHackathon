-- =============================================================================
-- MASSDX — COMPLETE DATABASE SCHEMA
-- PostgreSQL 15+ | SQLX compatible
-- =============================================================================
-- DESIGN PRINCIPLES:
--   - All PKs are UUIDs generated server-side (uuid_generate_v4())
--   - Mana and XP are APPEND-ONLY ledgers — never update a balance directly.
--     Balances are either cached on the user row (with ledger as source of truth)
--     or computed from the ledger. We cache for read performance.
--   - Monetary amounts (USD) stored as INTEGER cents to avoid float precision.
--   - Timestamps always UTC, always timestamptz.
--   - Soft deletes where data has historical value (listings, assets).
--   - Onchain data (bond wallet addresses, tx hashes) stored alongside
--     offchain mirrors so the backend can serve data without RPC calls.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
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
-- Central identity. One row per human. Linked to Twitch and an onchain wallet.
-- =============================================================================

CREATE TABLE users (
  id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

  -- Twitch identity
  twitch_id           TEXT UNIQUE NOT NULL,  -- Twitch numeric user ID string
  twitch_username     TEXT NOT NULL,
  twitch_display_name TEXT NOT NULL,
  twitch_avatar_url   TEXT,
  twitch_email        TEXT,                  -- only present if user grants scope

  -- Wallet (Dynamic embedded wallet, invisible to user)
  wallet_address      TEXT UNIQUE,           -- EVM address, null until wallet created
  wallet_created_at   TIMESTAMPTZ,

  -- Session
  -- JWT is stateless but we track refresh tokens for revocation
  refresh_token_hash  TEXT,                  -- bcrypt hash of current refresh token
  last_seen_at        TIMESTAMPTZ,

  -- Global stats (cached from ledgers — source of truth is mana_ledger/xp_ledger)
  -- These are updated via trigger or explicit service call after each ledger insert
  global_mana_balance BIGINT NOT NULL DEFAULT 0,  -- total mana across all streamers
  global_credits_balance_cents INTEGER NOT NULL DEFAULT 0, -- real money credits

  -- Flags
  is_admin            BOOLEAN NOT NULL DEFAULT FALSE,
  is_banned           BOOLEAN NOT NULL DEFAULT FALSE,
  welcome_drop_claimed BOOLEAN NOT NULL DEFAULT FALSE,
  anonymous_market    BOOLEAN NOT NULL DEFAULT FALSE, -- if true, show as "Anonymous" in feeds

  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_twitch_id ON users(twitch_id);
CREATE INDEX idx_users_wallet ON users(wallet_address) WHERE wallet_address IS NOT NULL;
CREATE INDEX idx_users_username_trgm ON users USING GIN (twitch_username gin_trgm_ops);

-- =============================================================================
-- STREAMERS
-- A streamer is also a user (they log in with Twitch too).
-- Separate table because streamers have configuration and marketplace settings
-- that regular users don't have.
-- =============================================================================

CREATE TABLE streamers (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Twitch channel info (mirrored from Twitch API, refreshed periodically)
  twitch_channel_id     TEXT UNIQUE NOT NULL,  -- same as user's twitch_id usually
  twitch_channel_name   TEXT NOT NULL,
  twitch_game_name      TEXT,
  twitch_follower_count INTEGER NOT NULL DEFAULT 0,
  twitch_subscriber_count INTEGER NOT NULL DEFAULT 0,
  is_live               BOOLEAN NOT NULL DEFAULT FALSE,
  live_viewer_count     INTEGER,
  last_live_at          TIMESTAMPTZ,

  -- Streamer branding (user-configurable)
  brand_color           TEXT NOT NULL DEFAULT '#D97B3A', -- hex, used for ambient/accents
  status_message        TEXT,                -- daily message shown on their page
  tier_config           JSONB,              -- custom tier names/icons if overriding defaults
  -- tier_config shape: { "1": { "name": "Wanderer", "icon": "🌿" }, "2": {...} }
  stream_embed_enabled  BOOLEAN NOT NULL DEFAULT TRUE,

  -- Marketplace config
  marketplace_active    BOOLEAN NOT NULL DEFAULT FALSE, -- must explicitly enable
  bonds_enabled         BOOLEAN NOT NULL DEFAULT FALSE,
  bonds_tranche_1_price_cents INTEGER,    -- price in cents for tranche 1 bonds
  bonds_tranche_2_price_cents INTEGER,
  bonds_tranche_3_price_cents INTEGER,
  bonds_tranche_1_supply INTEGER NOT NULL DEFAULT 500,
  bonds_tranche_2_supply INTEGER NOT NULL DEFAULT 300,
  bonds_tranche_3_supply INTEGER NOT NULL DEFAULT 200,
  bonds_revenue_share_bps INTEGER NOT NULL DEFAULT 500, -- basis points, 500 = 5%
  -- revenue_share_bps: percentage of marketplace revenue paid to bond holders
  -- e.g. 500 bps = 5% of every purchase goes to bond holders proportionally

  -- Chainlink CRE
  milestone_follower_threshold INTEGER,    -- follower count that triggers CRE workflow
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
-- Every user who has interacted with a streamer's community gets a membership row.
-- This is where per-streamer level, XP, and mana are cached.
-- Created lazily on first interaction (page visit + Twitch auth).
-- =============================================================================

CREATE TABLE user_streamer_memberships (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  -- Level system
  -- Level is derived from xp_balance but cached here for fast reads
  level           INTEGER NOT NULL DEFAULT 1,
  tier            INTEGER NOT NULL DEFAULT 1, -- 1-5, derived from level ranges
  xp_balance      BIGINT NOT NULL DEFAULT 0,  -- total XP in this streamer's community
  -- Level thresholds (hardcoded in app config, not DB):
  -- Lv1→2: 500 XP, Lv2→3: 1200, Lv3→4: 2400, Lv4→5: 4000, Lv5→6: 6000
  -- Lv6→7: 8500, Lv7→8: 11500, Lv8→9: 15000, Lv9→10: 20000, Lv10→11: 26000
  -- Lv11→12: 33000, Lv12→13: 41000 ...etc

  -- Tier names (default, overridable by streamer tier_config):
  -- Tier 1 (Lv 1-4):   Wanderer
  -- Tier 2 (Lv 5-9):   Scout → Initiate → Sentinel
  -- Tier 3 (Lv 10-14): Keeper
  -- Tier 4 (Lv 15-19): Warden
  -- Tier 5 (Lv 20+):   Archon → Harbinger → Sovereign → Eldritch

  -- Mana (per-streamer, social currency)
  mana_balance    BIGINT NOT NULL DEFAULT 0,  -- cached from mana_ledger
  -- mana_balance is updated every time a mana_ledger row is inserted for this membership

  -- Twitch watch metrics (rolling, reset weekly or kept cumulative — app decides)
  watch_time_minutes_total BIGINT NOT NULL DEFAULT 0,
  chat_messages_total      BIGINT NOT NULL DEFAULT 0,
  last_heartbeat_at        TIMESTAMPTZ,   -- last 5-min watch ping received

  -- Leaderboard rank (cached, recomputed by background job every 5 min)
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
-- Append-only. Never update or delete rows. Sum this table to get true balance.
-- The cached balance on user_streamer_memberships is the fast path.
-- Use this table for: auditing, breakdown display ("where did my mana come from"),
-- dispute resolution, analytics.
-- =============================================================================

CREATE TABLE mana_ledger (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  membership_id   UUID NOT NULL REFERENCES user_streamer_memberships(id) ON DELETE CASCADE,

  -- The transaction
  amount          BIGINT NOT NULL,  -- positive = gain, negative = spend
  source          mana_source NOT NULL,
  description     TEXT,  -- human-readable, e.g. "Watch time — 5 min block"
                         -- or "Purchased: Curse Token"

  -- Optional references to what caused this ledger entry
  asset_id        UUID,  -- if source = asset_activation or purchase_refund
  listing_id      UUID,  -- if this was a marketplace purchase
  achievement_key TEXT,  -- if source = achievement_claim

  -- Running balance AFTER this entry (denormalized for fast range queries)
  balance_after   BIGINT NOT NULL,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mana_ledger_membership ON mana_ledger(membership_id, created_at DESC);
CREATE INDEX idx_mana_ledger_user_streamer ON mana_ledger(user_id, streamer_id, created_at DESC);
CREATE INDEX idx_mana_ledger_source ON mana_ledger(source, created_at DESC);

-- =============================================================================
-- XP LEDGER
-- Same pattern as mana_ledger. XP is per-streamer-community.
-- =============================================================================

CREATE TABLE xp_ledger (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  membership_id   UUID NOT NULL REFERENCES user_streamer_memberships(id) ON DELETE CASCADE,

  amount          BIGINT NOT NULL,   -- almost always positive; can be negative for exploits/reversals
  source          xp_source NOT NULL,
  description     TEXT,

  -- Optional references
  asset_id        UUID,
  achievement_key TEXT,
  level_before    INTEGER,           -- snapshot of level when this XP was granted
  level_after     INTEGER,           -- if a level-up occurred, this differs from level_before
  -- When level_after > level_before, the backend should:
  --   1. Update membership level + tier
  --   2. Push a WebSocket "level_up" event to the user
  --   3. Trigger any level-unlocked perks

  balance_after   BIGINT NOT NULL,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_xp_ledger_membership ON xp_ledger(membership_id, created_at DESC);
CREATE INDEX idx_xp_ledger_user_streamer ON xp_ledger(user_id, streamer_id, created_at DESC);

-- =============================================================================
-- CREDITS LEDGER
-- Real money credits (USD cents). Global, not per-streamer.
-- Funded via Stripe. Spent on credit-priced assets.
-- =============================================================================

CREATE TABLE credits_ledger (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  amount_cents    INTEGER NOT NULL,  -- positive = top-up, negative = spend
  description     TEXT NOT NULL,

  -- References
  stripe_payment_intent_id  TEXT,   -- set on Stripe top-up
  stripe_charge_id          TEXT,
  asset_purchase_id         UUID,   -- set on spend
  bond_purchase_id          UUID,   -- set on bond buy

  balance_after_cents       INTEGER NOT NULL,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_credits_ledger_user ON credits_ledger(user_id, created_at DESC);

-- =============================================================================
-- ASSETS (TEMPLATE)
-- These are the asset DEFINITIONS created by streamers (or platform defaults).
-- Think of this as the item catalog. User ownership is in user_assets.
-- =============================================================================

CREATE TABLE assets (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  -- Identity
  name              TEXT NOT NULL,
  description       TEXT NOT NULL,
  emoji             TEXT NOT NULL DEFAULT '🎁',   -- display glyph
  asset_type        streamer_asset_type NOT NULL,
  rarity            asset_rarity NOT NULL DEFAULT 'common',

  -- Pricing
  price_type        asset_price_type NOT NULL DEFAULT 'mana',
  price_mana        BIGINT,          -- null if credit-only
  price_credits_cents INTEGER,       -- null if mana-only
  -- For 'both' type: user can choose which currency to use

  -- XP grant on purchase/activation
  xp_on_purchase    INTEGER NOT NULL DEFAULT 0,
  xp_on_activation  INTEGER NOT NULL DEFAULT 0,
  -- Mana grant on activation (some assets reward mana when used, e.g. Bounty wins)
  mana_on_activation BIGINT NOT NULL DEFAULT 0,

  -- Supply
  supply_type       TEXT NOT NULL DEFAULT 'unlimited',
  -- 'unlimited': no cap
  -- 'limited': supply_max units total ever
  -- 'streamer_mintable': streamer manually mints batches
  supply_max        INTEGER,         -- null if unlimited
  supply_minted     INTEGER NOT NULL DEFAULT 0,

  -- Level gate
  level_required    INTEGER NOT NULL DEFAULT 1,
  -- User must be at least this level in this streamer's community to purchase

  -- Visibility
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  is_featured       BOOLEAN NOT NULL DEFAULT FALSE,  -- pins to top of vault

  -- Asset behavior config (flexible JSONB for type-specific settings)
  behavior_config   JSONB,
  -- Examples by type:
  -- curse:   { "ban_duration_minutes": 10, "word_count": 1 }
  -- bounty:  { "window_minutes": 5, "reward_multiplier": 1.5 }
  -- decree:  { "duration_minutes": 60, "requires_streamer_approval": true }
  -- summon:  { "one_time_use": true, "streamer_bit": "their_signature_line" }
  -- omen:    { "payout_multiplier": 8, "resolution_minutes": 30 }

  -- Onchain (for assets that are minted as NFTs — optional, not all assets are onchain)
  is_onchain        BOOLEAN NOT NULL DEFAULT FALSE,
  contract_address  TEXT,
  token_id_start    BIGINT,          -- if ERC1155, the base token ID for this asset type

  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_assets_streamer ON assets(streamer_id, is_active);
CREATE INDEX idx_assets_rarity ON assets(streamer_id, rarity);
CREATE INDEX idx_assets_level ON assets(streamer_id, level_required);

-- =============================================================================
-- USER_ASSETS (OWNERSHIP)
-- Every time a user acquires an asset (purchase, drop, achievement reward),
-- a row is created here. This is the user's inventory.
-- =============================================================================

CREATE TABLE user_assets (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  asset_id        UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,

  -- Acquisition context
  acquired_via    TEXT NOT NULL,
  -- 'purchase_mana', 'purchase_credits', 'welcome_drop', 'achievement_reward',
  -- 'loot_drop', 'bond_holder_drop', 'secondary_market', 'admin_grant'
  acquired_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  acquisition_price_mana    BIGINT,        -- what was paid
  acquisition_price_cents   INTEGER,

  -- If bought on secondary market from another user
  seller_user_id  UUID REFERENCES users(id),

  -- Usage tracking
  is_consumed     BOOLEAN NOT NULL DEFAULT FALSE,  -- true for one-time-use assets
  consumed_at     TIMESTAMPTZ,
  -- Activation state (for assets with ongoing effects like curses, totems)
  is_active       BOOLEAN NOT NULL DEFAULT FALSE,
  activated_at    TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ,   -- for time-limited activations

  -- Onchain
  token_id        BIGINT,        -- if this specific instance is an NFT
  tx_hash         TEXT,          -- mint or transfer transaction

  -- Market
  is_listed       BOOLEAN NOT NULL DEFAULT FALSE,  -- currently listed for resale

  -- Value tracking (for "items that have gone up in value" display)
  -- We periodically snapshot the current floor price of this asset type
  -- and store it here for the dashboard display
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
-- When a user activates/uses an asset (fires a curse, places a bounty, etc.),
-- we record the full event here. This drives the overlay, the activity feed,
-- and the XP/mana grants.
-- =============================================================================

CREATE TABLE asset_activations (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_asset_id     UUID NOT NULL REFERENCES user_assets(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  asset_id          UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,

  activated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Target (for assets that affect another user — curses, bounties)
  target_username   TEXT,      -- Twitch username of the target
  target_user_id    UUID REFERENCES users(id),

  -- Outcome
  resolved          BOOLEAN NOT NULL DEFAULT FALSE,
  resolved_at       TIMESTAMPTZ,
  outcome           TEXT,      -- 'success', 'failed', 'expired', 'cancelled'
  outcome_detail    JSONB,
  -- For curse: { "banned_word": "gg", "triggered_by": "target_username", "triggered_at": "..." }
  -- For bounty: { "condition_met": true, "participants": ["user1", "user2"] }
  -- For omen:  { "prediction": "text", "correct": true, "payout_mana": 3200 }

  -- XP/mana granted as result
  xp_granted        INTEGER,
  mana_granted      BIGINT,

  -- PubSub payload sent to Twitch Extension overlay
  pubsub_payload    JSONB,
  pubsub_sent_at    TIMESTAMPTZ
);

CREATE INDEX idx_activations_streamer ON asset_activations(streamer_id, activated_at DESC);
CREATE INDEX idx_activations_user ON asset_activations(user_id, activated_at DESC);

-- =============================================================================
-- SECONDARY MARKET LISTINGS
-- Users can list their user_assets for sale to other users.
-- Priced in mana only for the community-facing market.
-- =============================================================================

CREATE TABLE listings (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_asset_id   UUID NOT NULL REFERENCES user_assets(id) ON DELETE CASCADE,
  seller_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  streamer_id     UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  asset_id        UUID NOT NULL REFERENCES assets(id) ON DELETE CASCADE,

  price_mana      BIGINT,         -- null if credit listing
  price_cents     INTEGER,        -- null if mana listing

  status          listing_status NOT NULL DEFAULT 'active',

  -- Who bought it
  buyer_id        UUID REFERENCES users(id),
  sold_at         TIMESTAMPTZ,

  -- Platform fee (taken from seller on sale)
  -- Default: 5% to platform, 2.5% to bond holders of this streamer
  platform_fee_bps INTEGER NOT NULL DEFAULT 500,
  bond_fee_bps     INTEGER NOT NULL DEFAULT 250,

  listed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at      TIMESTAMPTZ,    -- null = no expiry
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_listings_streamer ON listings(streamer_id, status) WHERE status = 'active';
CREATE INDEX idx_listings_asset ON listings(asset_id, status);
CREATE INDEX idx_listings_seller ON listings(seller_id);

-- =============================================================================
-- BONDS
-- Each row is one bond held by one user for one streamer.
-- Bonds are ERC-20 or ERC-1155 onchain, mirrored here for fast reads.
-- =============================================================================

CREATE TABLE bonds (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,
  holder_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Quantity held (can hold multiple bonds in one row, or one row per bond — we use one row per user per streamer)
  quantity          INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),

  -- Tranche context (when purchased)
  tranche           bond_tranche NOT NULL DEFAULT 'tranche_1',

  -- Pricing
  avg_cost_cents    INTEGER NOT NULL,   -- weighted average cost in cents
  current_price_cents INTEGER,          -- last known market price, updated by background job

  -- Revenue share
  -- Each bond represents revenue_share_bps / total_bonds_issued basis points of revenue
  -- The actual yield is computed dynamically: (marketplace_revenue * streamer_bps * holder_quantity) / total_supply
  revenue_share_bps INTEGER NOT NULL,   -- snapshot at time of purchase
  total_supply_at_purchase INTEGER NOT NULL,  -- total bonds outstanding when purchased

  -- Yield tracking
  total_yield_earned_cents INTEGER NOT NULL DEFAULT 0,
  last_yield_at            TIMESTAMPTZ,

  -- Onchain mirror
  wallet_address    TEXT NOT NULL,      -- holder's wallet
  contract_address  TEXT,              -- BondRegistry contract
  onchain_token_id  BIGINT,
  mint_tx_hash      TEXT,

  -- Buyout
  buyout_eligible   BOOLEAN NOT NULL DEFAULT TRUE,
  -- Streamer can trigger a forced buyout at 2.5x last 90-day high

  purchased_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(streamer_id, holder_user_id)
  -- One row per user per streamer. quantity tracks how many bonds they hold.
  -- If user buys more bonds, UPDATE quantity and recalculate avg_cost_cents.
);

CREATE INDEX idx_bonds_streamer ON bonds(streamer_id);
CREATE INDEX idx_bonds_holder ON bonds(holder_user_id);
CREATE INDEX idx_bonds_wallet ON bonds(wallet_address);

-- =============================================================================
-- BOND YIELD EVENTS
-- Every time marketplace revenue is distributed to bond holders,
-- we record the distribution event and each holder's payout.
-- =============================================================================

CREATE TABLE bond_yield_events (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  streamer_id       UUID NOT NULL REFERENCES streamers(id) ON DELETE CASCADE,

  -- What triggered this yield event
  trigger_type      TEXT NOT NULL,
  -- 'marketplace_sale', 'listing_sale', 'manual_distribution'
  trigger_reference UUID,   -- listing_id or user_asset purchase that generated revenue

  -- Total revenue being distributed
  gross_revenue_cents    INTEGER NOT NULL,
  bond_pool_cents        INTEGER NOT NULL,  -- gross * bond_fee_bps
  total_bonds_outstanding INTEGER NOT NULL,

  distributed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE bond_yield_payouts (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  yield_event_id    UUID NOT NULL REFERENCES bond_yield_events(id) ON DELETE CASCADE,
  bond_id           UUID NOT NULL REFERENCES bonds(id) ON DELETE CASCADE,
  holder_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  bonds_held        INTEGER NOT NULL,
  payout_cents      INTEGER NOT NULL,   -- their proportional share
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