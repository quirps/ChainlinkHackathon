
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