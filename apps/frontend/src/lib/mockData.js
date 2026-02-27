// Mirrors getCommunityPageData() response shape exactly.
// Swap the one import in CommunityPage.jsx when the backend is live.

export const MOCK_PAGE_DATA = {
  streamer: {
    id: 'streamer-nightowl-001',
    twitchChannelName: 'nightowltv',
    twitchDisplayName: 'NightOwlTV',
    twitchAvatarEmoji: '🦉',
    brandColor: '#D97B3A',
    statusMessage: 'Currently running the new ranked ladder — chaos ensues.',
    tagline: 'No sleep until the boss is dead.',
    isLive: true,
    liveViewerCount: 1420,
    followerCount: 48200,
    subscribePrice: 499,
    bondsEnabled: true,
  },

  membership: {
    userId: 'user-demo-001',
    streamerId: 'streamer-nightowl-001',
    level: 12,
    tier: 3,
    tierName: 'Keeper of Embers',
    tierGlyph: '🜂',
    xpBalance: 3240,
    xpToNextLevel: 1560,
    nextLevelXp: 4800,
    manaBalance: 12480,
    leaderboardRank: 7,
    perks: [
      { value: '8%',    label: 'off all loot boxes' },
      { value: '+12 XP', label: 'per action' },
      { value: 'Early', label: 'drop window access' },
      { value: '+0.2%', label: 'bond yield bonus' },
    ],
  },

  assets: [
    {
      id: 'asset-001', streamerId: 'streamer-nightowl-001',
      name: 'Curse Token',
      description: 'Hex a target chatter with a banned word for 10 minutes.',
      emoji: '💀', rarity: 'legendary', priceType: 'mana',
      priceMana: 4800, priceCreditsCents: null,
      xpOnPurchase: 120, levelRequired: 10,
      isActive: true, isFeatured: true, supplyRemaining: null,
      sellerDisplayName: null,
    },
    {
      id: 'asset-002', streamerId: 'streamer-nightowl-001',
      name: 'Omen of Fury',
      description: 'Predict a stream outcome. 8× payout if correct.',
      emoji: '🔮', rarity: 'legendary', priceType: 'mana',
      priceMana: 6200, priceCreditsCents: null,
      xpOnPurchase: 150, levelRequired: 12,
      isActive: true, isFeatured: true, supplyRemaining: null,
      sellerDisplayName: null,
    },
    {
      id: 'asset-003', streamerId: 'streamer-nightowl-001',
      name: 'Decree Scroll',
      description: 'Issue a binding command to chat for 60 minutes.',
      emoji: '📜', rarity: 'epic', priceType: 'mana',
      priceMana: 2800, priceCreditsCents: null,
      xpOnPurchase: 80, levelRequired: 8,
      isActive: true, isFeatured: false, supplyRemaining: 45,
      sellerDisplayName: null,
    },
    {
      id: 'asset-004', streamerId: 'streamer-nightowl-001',
      name: 'Summon Scroll',
      description: 'Call forth a one-time interaction with the streamer.',
      emoji: '🌀', rarity: 'epic', priceType: 'credits',
      priceMana: null, priceCreditsCents: 299,
      xpOnPurchase: 200, levelRequired: 5,
      isActive: true, isFeatured: false, supplyRemaining: 12,
      sellerDisplayName: null,
    },
    {
      id: 'asset-005', streamerId: 'streamer-nightowl-001',
      name: 'Totem of Watching',
      description: 'Passive aura. +5% Mana while in inventory.',
      emoji: '🗿', rarity: 'rare', priceType: 'mana',
      priceMana: 1200, priceCreditsCents: null,
      xpOnPurchase: 40, levelRequired: 5,
      isActive: true, isFeatured: false, supplyRemaining: null,
      sellerDisplayName: null,
    },
    {
      id: 'asset-006', streamerId: 'streamer-nightowl-001',
      name: 'Bounty Mark',
      description: 'Place a bounty. Reward pool distributed on condition met.',
      emoji: '🎯', rarity: 'rare', priceType: 'mana',
      priceMana: 1800, priceCreditsCents: null,
      xpOnPurchase: 60, levelRequired: 7,
      isActive: true, isFeatured: false, supplyRemaining: null,
      sellerDisplayName: null,
    },
    {
      id: 'asset-007', streamerId: 'streamer-nightowl-001',
      name: 'Sound Byte',
      description: 'Trigger a 5-second audio clip during stream.',
      emoji: '🔊', rarity: 'common', priceType: 'mana',
      priceMana: 400, priceCreditsCents: null,
      xpOnPurchase: 10, levelRequired: 1,
      isActive: true, isFeatured: false, supplyRemaining: null,
      sellerDisplayName: null,
    },
    {
      id: 'asset-008', streamerId: 'streamer-nightowl-001',
      name: 'Relic Fragment',
      description: 'A piece of something ancient. Combine 5 for a Legendary.',
      emoji: '🧩', rarity: 'common', priceType: 'mana',
      priceMana: 300, priceCreditsCents: null,
      xpOnPurchase: 10, levelRequired: 1,
      isActive: true, isFeatured: false, supplyRemaining: 180,
      sellerDisplayName: 'voidrunner_88',
    },
  ],

  userInventory: [
    {
      id: 'ua-001', assetId: 'asset-005',
      name: 'Totem of Watching', emoji: '🗿', rarity: 'rare',
      isConsumed: false, isActive: true, isListed: false,
      acquiredAt: '2025-02-20T12:00:00Z',
      acquisitionPriceMana: 1200, lastKnownFloorMana: 1400,
      unrealizedGainMana: 200,
      sellerDisplayName: null, quantity: 1,
    },
    {
      id: 'ua-002', assetId: 'asset-007',
      name: 'Sound Byte', emoji: '🔊', rarity: 'common',
      isConsumed: false, isActive: false, isListed: false,
      acquiredAt: '2025-02-22T18:00:00Z',
      acquisitionPriceMana: 400, lastKnownFloorMana: 400,
      unrealizedGainMana: 0,
      sellerDisplayName: null, quantity: 3,
    },
  ],

  leaderboard: [
    { rank: 1, userId: 'u-01', displayName: 'voidrunner_88', avatarEmoji: '🌌', level: 18, tier: 4, tierName: 'Warden',          xpBalance: 22400, isCurrentUser: false },
    { rank: 2, userId: 'u-02', displayName: 'solstice_k',    avatarEmoji: '☀️', level: 16, tier: 4, tierName: 'Warden',          xpBalance: 18900, isCurrentUser: false },
    { rank: 3, userId: 'u-03', displayName: 'cryo_knight',   avatarEmoji: '❄️', level: 15, tier: 4, tierName: 'Warden',          xpBalance: 16200, isCurrentUser: false },
    { rank: 4, userId: 'u-04', displayName: 'axiom_cast',    avatarEmoji: '⚡', level: 14, tier: 3, tierName: 'Keeper',          xpBalance: 13800, isCurrentUser: false },
    { rank: 5, userId: 'u-05', displayName: 'dusk_fall_99',  avatarEmoji: '🌙', level: 13, tier: 3, tierName: 'Keeper',          xpBalance: 11400, isCurrentUser: false },
    { rank: 6, userId: 'u-06', displayName: 'prism_plays',   avatarEmoji: '🔮', level: 12, tier: 3, tierName: 'Keeper',          xpBalance: 9800,  isCurrentUser: false },
    { rank: 7, userId: 'demo', displayName: 'you (demo)',    avatarEmoji: '👤', level: 12, tier: 3, tierName: 'Keeper of Embers', xpBalance: 3240,  isCurrentUser: true  },
  ],

  xpBreakdown: [
    { label: 'Asset purchases', amount: 1240, percentOfTotal: 82 },
    { label: 'Watch time',      amount: 180,  percentOfTotal: 12 },
    { label: 'Chat activity',   amount: 90,   percentOfTotal: 6  },
  ],

  activityFeed: [
    { id: 'ev-01', displayName: 'voidrunner_88', eventType: 'asset_purchased', subjectName: 'Curse Token',   subjectRarity: 'legendary', subjectEmoji: '💀', detailText: 'acquired',           timeAgo: '14s', avatarEmoji: '🌌' },
    { id: 'ev-02', displayName: 'solstice_k',    eventType: 'asset_activated', subjectName: 'Omen of Fury',  subjectRarity: 'legendary', subjectEmoji: '🔮', detailText: 'activated',          timeAgo: '1m',  avatarEmoji: '☀️' },
    { id: 'ev-03', displayName: 'cryo_knight',   eventType: 'level_up',        subjectName: null,           subjectRarity: null,        subjectEmoji: null, detailText: 'reached Level 15',   timeAgo: '3m',  avatarEmoji: '❄️' },
    { id: 'ev-04', displayName: 'axiom_cast',    eventType: 'asset_purchased', subjectName: 'Bounty Mark',   subjectRarity: 'rare',      subjectEmoji: '🎯', detailText: 'acquired',           timeAgo: '5m',  avatarEmoji: '⚡' },
    { id: 'ev-05', displayName: 'dusk_fall_99',  eventType: 'asset_activated', subjectName: 'Sound Byte',    subjectRarity: 'common',    subjectEmoji: '🔊', detailText: 'activated',          timeAgo: '7m',  avatarEmoji: '🌙' },
    { id: 'ev-06', displayName: 'prism_plays',   eventType: 'achievement',     subjectName: 'First Blood',   subjectRarity: null,        subjectEmoji: '🏆', detailText: 'claimed achievement', timeAgo: '11m', avatarEmoji: '🔮' },
  ],

  progressionSteps: [
    { level: 10, icon: '🗡',  name: 'Initiate of the Vault', detail: 'Unlocks epic asset tier',    status: 'done'    },
    { level: 12, icon: '🜂',  name: 'Keeper of Embers',      detail: 'Current tier — 8% discount', status: 'current' },
    { level: 15, icon: '🏰', name: 'Warden of Ash',          detail: 'Unlocks decree assets',      status: 'locked'  },
    { level: 20, icon: '🌀', name: "Archon's Veil",          detail: 'Exclusive seasonal drops',   status: 'locked'  },
  ],

  achievements: [
    {
      key: 'proof_of_humanity', name: 'Proof of Humanity', icon: '🤖',
      description: 'Complete 50 unique human interactions.',
      status: 'claimable', progressValue: 50, progressRequired: 50,
      rewardMana: 2000, rewardXp: 500,
      rewardDescription: '+2,000 Mana, +500 XP, exclusive badge',
    },
    {
      key: 'first_blood', name: 'First Blood', icon: '🔥',
      description: 'Make your first asset purchase.',
      status: 'claimed', progressValue: 1, progressRequired: 1,
      rewardMana: 500, rewardXp: 100,
      rewardDescription: '+500 Mana, +100 XP',
    },
    {
      key: 'voice_of_realm', name: 'Voice of the Realm', icon: '💬',
      description: 'Send 100 messages in any watched stream.',
      status: 'in_progress', progressValue: 67, progressRequired: 100,
      rewardMana: 300, rewardXp: 200,
      rewardDescription: '+300 Mana, +200 XP',
    },
    {
      key: 'keeper_ascended', name: 'Keeper Ascended', icon: '🜂',
      description: 'Reach Tier III — Keeper of Embers.',
      status: 'claimable', progressValue: 1, progressRequired: 1,
      rewardMana: 1000, rewardXp: 0,
      rewardDescription: '+1,000 Mana',
    },
    {
      key: 'early_backer', name: 'Early Backer', icon: '🏰',
      description: 'Purchase a Bond before this streamer reaches 50k followers.',
      status: 'locked', progressValue: 0, progressRequired: 1,
      rewardMana: 0, rewardXp: 500,
      rewardDescription: '+500 XP, Founding asset drop',
    },
  ],
}

// ─── Trader / Market page mock data ───────────────────────────────────────────
// Mirrors getMarketPageData() response shape.

export const MOCK_MARKET_DATA = {
  streamers: [
    { id: 'nightowltv', name: 'NightOwlTV',  avi: '🦉', cat: 'FPS',     price: 4.20,  chg: +4.2, yield: 2.1, supplyLeft: 312, holders: 89,  momentum: 78, tranche: 1, live: true  },
    { id: 'prism',      name: 'PrismPlays',  avi: '🔮', cat: 'Variety', price: 6.80,  chg: -1.1, yield: 3.4, supplyLeft: 44,  holders: 211, momentum: 35, tranche: 2, live: true  },
    { id: 'voidwalker', name: 'VoidWalker',  avi: '🌌', cat: 'RPG',     price: 2.10,  chg: +8.7, yield: 1.2, supplyLeft: 488, holders: 34,  momentum: 92, tranche: 1, live: false },
    { id: 'solstice',   name: 'SolsticeGG',  avi: '☀️', cat: 'Esports', price: 11.40, chg: +2.3, yield: 4.8, supplyLeft: 8,   holders: 443, momentum: 55, tranche: 3, live: true  },
    { id: 'cryo',       name: 'CryoKnight',  avi: '❄️', cat: 'FPS',     price: 3.50,  chg: -0.4, yield: 1.8, supplyLeft: 201, holders: 67,  momentum: 40, tranche: 1, live: false },
    { id: 'axiom',      name: 'AxiomCast',   avi: '⚡', cat: 'Esports', price: 8.90,  chg: +5.7, yield: 3.9, supplyLeft: 55,  holders: 178, momentum: 85, tranche: 2, live: true  },
    { id: 'dusk',       name: 'DuskFall',    avi: '🌙', cat: 'IRL',     price: 1.80,  chg:  0.0, yield: 0.9, supplyLeft: 390, holders: 22,  momentum: 20, tranche: 1, live: false },
    { id: 'neon',       name: 'NeonDrifter', avi: '🎮', cat: 'RPG',     price: 5.20,  chg: -2.1, yield: 2.6, supplyLeft: 127, holders: 94,  momentum: 28, tranche: 2, live: false },
    { id: 'blaze',      name: 'BlazeRunner', avi: '🔥', cat: 'FPS',     price: 7.60,  chg: +3.4, yield: 3.2, supplyLeft: 72,  holders: 156, momentum: 67, tranche: 2, live: true  },
    { id: 'luna',       name: 'LunaStream',  avi: '🌛', cat: 'IRL',     price: 2.90,  chg: +1.8, yield: 1.5, supplyLeft: 260, holders: 41,  momentum: 45, tranche: 1, live: false },
  ],
  myBonds: [
    { id: 'nightowltv', name: 'NightOwlTV', qty: 3, cost: 3.80, current: 4.20 },
    { id: 'prism',      name: 'PrismPlays', qty: 1, cost: 7.20, current: 6.80 },
    { id: 'voidwalker', name: 'VoidWalker', qty: 5, cost: 1.90, current: 2.10 },
  ],
  yieldEvents: [
    { type: 'up',  actor: 'NightOwlTV',  action: 'bond yield',      detail: '+$0.84',          time: '2m'  },
    { type: 'neu', actor: 'PrismPlays',  action: 'listing sold',    detail: 'fee distributed', time: '8m'  },
    { type: 'up',  actor: 'VoidWalker',  action: 'bond yield',      detail: '+$2.10',          time: '15m' },
    { type: 'up',  actor: 'AxiomCast',   action: 'watchtime spike', detail: 'community bonus', time: '22m' },
    { type: 'dn',  actor: 'CryoKnight',  action: 'stream ended',    detail: 'yield paused',    time: '41m' },
    { type: 'up',  actor: 'SolsticeGG',  action: 'tournament win',  detail: 'volume surge',    time: '1h'  },
    { type: 'neu', actor: 'NightOwlTV',  action: 'new asset drop',  detail: '32 purchases',    time: '2h'  },
  ],
}

// ─── Landing page mock data ────────────────────────────────────────────────────

export const MOCK_LANDING_DATA = {
  stats: [
    { num: '14,208', label: 'Active viewers'    },
    { num: '$247K',  label: 'Bond value locked' },
    { num: '89',     label: 'Streamers live'    },
    { num: '3.4%',   label: 'Avg monthly yield' },
  ],
  liveStreamers: [
    { id: 'nightowltv', name: 'NightOwlTV', avi: '🦉', live: true,  viewers: '14.2K', bond: '$4.20', chg: '+4.2%', pos: true  },
    { id: 'prism',      name: 'PrismPlays', avi: '🔮', live: true,  viewers: '8.7K',  bond: '$6.80', chg: '-1.1%', pos: false },
    { id: 'voidwalker', name: 'VoidWalker', avi: '🌌', live: false, viewers: '—',     bond: '$2.10', chg: '+8.7%', pos: true  },
  ],
}