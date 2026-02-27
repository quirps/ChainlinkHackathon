import { Routes, Route } from 'react-router-dom'
import { CommunityPage } from './pages/CommunityPage'
import { DevPanel } from './components/dev/DevPanel'

export default function App() {
  return (
    <>
      <Routes>
        <Route path="/streamers/:channelName" element={<CommunityPage />} />
        <Route path="/" element={<CommunityPage />} />
      </Routes>
      <DevPanel />
    </>
  )
}