import { Routes, Route, Navigate } from 'react-router-dom'
import { LandingPage }   from './pages/LandingPage'
import { CommunityPage } from './pages/CommunityPage'
import { TraderPage }    from './pages/TraderPage'
import { DevPanel }      from './components/dev/DevPanel'

export default function App() {
  return (
    <>
      <Routes>
        {/* Public marketing */}
        <Route path="/"                         element={<LandingPage />} />

        {/* Market / bonds / trader */}
        <Route path="/market"                   element={<TraderPage />} />

        {/* Streamer community pages */}
        <Route path="/streamers/:channelName"   element={<CommunityPage />} />

        {/* Dev shortcut — hit /dev to go straight to a community page */}
        <Route path="/dev"                      element={<Navigate to="/streamers/nightowltv" replace />} />
      </Routes>
      <DevPanel />
    </>
  )
}