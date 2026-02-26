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

