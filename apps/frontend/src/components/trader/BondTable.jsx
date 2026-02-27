import styles from './BondTable.module.css'

const TABS = [
  { id: 'bonds',    label: 'Bonds',    stat: 'MDX-B', chg: '+2.4%', pos: true  },
  { id: 'assets',   label: 'Assets',   stat: 'MDX-A', chg: '+0.9%', pos: true  },
  { id: 'listings', label: 'Listings', stat: '247',   chg: 'active', pos: null  },
]

const COLUMNS = [
  { key: 'name',       label: 'Streamer',    align: 'left'  },
  { key: 'price',      label: 'Price',       align: 'right' },
  { key: 'chg',        label: '24h Chg',     align: 'right' },
  { key: 'yield',      label: 'Yield',       align: 'right' },
  { key: 'supplyLeft', label: 'Supply Left', align: 'right' },
  { key: 'holders',    label: 'Holders',     align: 'right' },
  { key: 'momentum',   label: '7d Momentum', align: 'right' },
  { key: 'tranche',    label: 'Tranche',     align: 'right' },
  { key: 'live',       label: 'Live',        align: 'right' },
]

export function BondTable({ rows, sortCol, sortDir, activeTab, selectedId, onSort, onTabChange, onSelectRow }) {
  return (
    <div className={styles.wrap}>
      {/* Tab bar */}
      <div className={styles.tabBar}>
        {TABS.map(tab => (
          <div
            key={tab.id}
            className={`${styles.tab} ${activeTab === tab.id ? styles.tabOn : ''}`}
            onClick={() => onTabChange(tab.id)}
          >
            <span>{tab.label}</span>
            <div className={styles.tabStat}>
              <span className={styles.tabStatVal}>{tab.stat}</span>
              <span className={`${styles.tabStatChg} ${tab.pos === true ? styles.up : tab.pos === false ? styles.dn : styles.neu}`}>
                {tab.chg}
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Table */}
      <div className={styles.tableWrap}>
        <table className={styles.table}>
          <thead>
            <tr>
              {COLUMNS.map(col => (
                <th
                  key={col.key}
                  className={`${col.align === 'left' ? styles.thLeft : ''} ${sortCol === col.key ? styles.thSorted : ''}`}
                  onClick={() => onSort(col.key)}
                >
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {rows.map(s => (
              <BondRow
                key={s.id}
                streamer={s}
                selected={selectedId === s.id}
                onClick={() => onSelectRow(s.id)}
              />
            ))}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function BondRow({ streamer: s, selected, onClick }) {
  const chgPos = s.chg > 0 ? styles.up : s.chg < 0 ? styles.dn : styles.neu

  return (
    <tr
      className={`${styles.row} ${selected ? styles.rowSelected : ''}`}
      onClick={onClick}
    >
      <td>
        <div className={styles.streamerCell}>
          <div className={styles.avi}>{s.avi}</div>
          <div>
            <div className={styles.streamerName}>{s.name}</div>
            <div className={styles.streamerCat}>{s.cat}</div>
          </div>
        </div>
      </td>
      <td className={styles.tdRight}>${s.price.toFixed(2)}</td>
      <td className={`${styles.tdRight} ${chgPos}`}>
        {s.chg > 0 ? '+' : ''}{s.chg.toFixed(1)}%
      </td>
      <td className={`${styles.tdRight} ${styles.up}`}>{s.yield.toFixed(1)}%</td>
      <td className={styles.tdRight}>{s.supplyLeft}</td>
      <td className={styles.tdRight}>{s.holders}</td>
      <td>
        <div className={styles.momentumCell}>
          <span className={`${chgPos} ${styles.momentumNum}`}>{s.momentum}</span>
          <div className={styles.momentumTrack}>
            <div className={`${styles.momentumFill} ${chgPos}`} style={{ width: `${s.momentum}%` }} />
          </div>
        </div>
      </td>
      <td>
        <span className={`${styles.trancheBadge} ${styles[`t${s.tranche}`]}`}>T{s.tranche}</span>
      </td>
      <td>
        <div className={styles.liveCell}>
          <div className={`${styles.livePip} ${s.live ? styles.livePipOn : styles.livePipOff}`} />
          <span className={s.live ? styles.up : styles.neu}>{s.live ? 'Live' : '—'}</span>
        </div>
      </td>
    </tr>
  )
}