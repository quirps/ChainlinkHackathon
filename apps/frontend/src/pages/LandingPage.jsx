import { useState, useEffect } from 'react'
import { useDynamicContext } from '@dynamic-labs/sdk-react-core'
import { useUserStore } from '../stores/useUserStore'
import { useUIStore } from '../stores/useUIStore'
import { LandingNav }       from '../components/landing/LandingNav'
import { HeroSection }      from '../components/landing/HeroSection'
import { FeaturesSection }  from '../components/landing/FeaturesSection'
import { HowItWorks }       from '../components/landing/HowItWorks'
import { BondsSection }     from '../components/landing/BondsSection'
import { CtaSection }       from '../components/landing/CtaSection'
import { LandingFooter }    from '../components/landing/LandingFooter'
import styles from './LandingPage.module.css'

export function LandingPage() {
  const [scrolled, setScrolled] = useState(false)

  const user              = useUserStore(s => s.user)
  const openAuth          = useUIStore(s => s.openCommunityAuthModal)
  const { user: dynUser } = useDynamicContext()
  const isConnected       = !!dynUser || !!user

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20)
    window.addEventListener('scroll', onScroll)
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <div className={styles.root}>
      <LandingNav scrolled={scrolled} isConnected={isConnected} onConnect={openAuth} />
      <HeroSection    onConnect={openAuth} />
      <FeaturesSection />
      <HowItWorks />
      <BondsSection />
      <CtaSection     onConnect={openAuth} />
      <LandingFooter />
    </div>
  )
}