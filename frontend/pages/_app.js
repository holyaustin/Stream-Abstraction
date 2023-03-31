import '../styles/globals.css'

import { MoralisProvider } from 'react-moralis'
import { Toaster } from 'react-hot-toast'


function MyApp({ Component, pageProps }) {


  return (
    /**
    <MoralisProvider appId={process.env.NEXT_PUBLIC_MORALIS_APP_ID} serverUrl={process.env.NEXT_PUBLIC_MORALIS_SERVER_URL}>
     */
    <MoralisProvider
    serverUrl="https://hpz4yq50hr8y.usemoralis.com:2053/server"
    appId="FaLY0U96izeaTHPkmvxHUq87YIejSYU0KMBiHS5M"
  >
      <Toaster position='bottom-right' />
      <Component {...pageProps} />
    </MoralisProvider>
  )

}

export default MyApp
