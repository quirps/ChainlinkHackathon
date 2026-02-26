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