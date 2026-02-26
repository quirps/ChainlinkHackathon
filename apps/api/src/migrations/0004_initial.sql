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
