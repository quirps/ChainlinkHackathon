import { useState, useEffect } from 'react'
import { useDynamicContext } from '@dynamic-labs/sdk-react-core'
import { useUserStore } from '../stores/useUserStore'
import { useUIStore } from '../stores/useUIStore'
import { MarketChrome }   from '../components/trader/MarketChrome'
import { MarketSidebar }  from '../components/trader/MarketSidebar'
import { BondTable }      from '../components/trader/BondTable'
import { BondDetail }     from '../components/trader/BondDetail'
import { PortfolioPanel } from '../components/trader/PortfolioPanel'
import { YieldFeed }      from '../components/trader/YieldFeed'
import { QuickBuy }       from '../components/trader/QuickBuy'
import { MOCK_MARKET_DATA } from '../lib/mockData'
import styles from './TraderPage.module.css'

const USE_MOCK = true

export function TraderPage() {
  const [rows, setRows]             = useState(MOCK_MARKET_DATA.streamers)
  const [category, setCategory]     = useState('All')
  const [sortCol, setSortCol]       = useState('chg')
  const [sortDir, setSortDir]       = useState(-1)
  const [selectedId, setSelectedId] = useState(null)
  const [activeTab, setActiveTab]   = useState('bonds')
  const [qty, setQty]               = useState(1)

  const { user: dynamicUser } = useDynamicContext()
  const user         = useUserStore(s => s.user)
  const openWeb3Auth = useUIStore(s => s.openWeb3AuthModal)
  const isConnected  = !!dynamicUser || !!user

  // Simulate live price drift
  useEffect(() => {
    const id = setInterval(() => {
      setRows(prev => prev.map(s => ({
        ...s,
        price: Math.max(0.10, s.price + (Math.random() - 0.49) * 0.06),
      })))
    }, 4000)
    return () => clearInterval(id)
  }, [])

  // Sorted + filtered rows
  const visible = rows
    .filter(s => category === 'All' || s.cat === category)
    .sort((a, b) => {
      const KEYS = { chg: 'chg', price: 'price', yield: 'yield', holders: 'holders', momentum: 'momentum', supplyLeft: 'supplyLeft' }
      const k = KEYS[sortCol]
      return k ? (a[k] - b[k]) * sortDir : 0
    })

  function handleSort(col) {
    if (sortCol === col) setSortDir(d => d * -1)
    else { setSortCol(col); setSortDir(-1) }
  }

  function handleSelectRow(id) {
    setSelectedId(prev => prev === id ? null : id)
    setQty(1)
  }

  const selectedStreamer = rows.find(s => s.id === selectedId) ?? null

  return (
    <div className={styles.root}>
      <MarketChrome streamers={rows} />

      <div className={styles.body}>
        <MarketSidebar
          category={category}
          onCategory={setCategory}
          myBonds={MOCK_MARKET_DATA.myBonds}
          streamers={rows}
          onSelectRow={handleSelectRow}
        />

        <main className={styles.colMain}>
          <BondTable
            rows={visible}
            sortCol={sortCol}
            sortDir={sortDir}
            activeTab={activeTab}
            selectedId={selectedId}
            onSort={handleSort}
            onTabChange={setActiveTab}
            onSelectRow={handleSelectRow}
          />
          {selectedStreamer && (
            <BondDetail
              streamer={selectedStreamer}
              qty={qty}
              onQtyChange={setQty}
              onClose={() => setSelectedId(null)}
              isConnected={isConnected}
              onOpenAuth={openWeb3Auth}
            />
          )}
        </main>

        <aside className={styles.colRight}>
          <PortfolioPanel myBonds={MOCK_MARKET_DATA.myBonds} />
          <YieldFeed events={MOCK_MARKET_DATA.yieldEvents} />
          <QuickBuy streamers={rows} />
        </aside>
      </div>
    </div>
  )
}