import Head from 'next/head'
import HeroSection from '../components/HeroSection'
import Container from '../components/Container'
import Authkit from '../components/Authkit'
import Navbar from '../components/Navbar'
import { useMoralis } from 'react-moralis';
export default function Home() {


  return (
    <div className='min-h-screen flex flex-col'>
      <Head>
        <title>Stream Abstraction</title>
        <meta name="description" content="Stream Abstraction" />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      <Navbar />
      <main >
        <Container>

          <HeroSection />
          <Authkit />

        </Container>
      </main>
    </div>
  )
}
