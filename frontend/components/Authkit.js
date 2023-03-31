import { SafeAuthKit, SafeAuthProviderType } from '@safe-global/auth-kit'



const safeAuthKit = await SafeAuthKit.init(SafeAuthProviderType.Web3Auth, {
  chainId: '0x80001',
  authProviderConfig: {
    rpcTarget: 'https://rpc-mumbai.matic.today', // Add your RPC e.g. https://goerli.infura.io/v3/<your project id>
    clientId: 'BLYfbg5cVzf73IpcvA5hE5gPyXsEYgs_7PYsGF7ZK-0qvEiOisvny2fzNmLHGjlrLv_gznJSkvmNGVPg6UYQiAc', // Add your client id. Get it from the Web3Auth dashboard
    network: 'testnet' | 'mainnet', // The network to use for the Web3Auth modal. Use 'testnet' while developing and 'mainnet' for production use
    theme: 'light' | 'dark', // The theme to use for the Web3Auth modal
    modalConfig: {
      // The modal config is optional and it's used to customize the Web3Auth modal
      // Check the Web3Auth documentation for more info: https://web3auth.io/docs/sdk/web/modal/whitelabel#initmodal
    }
  }
})

const login = async () => {
  if (!safeAuth) return

  const response = await safeAuth.signIn()
  console.log('SIGN IN RESPONSE: ', response)

  //setSafeAuthSignInResponse(response)
  //setProvider(safeAuth.getProvider() as SafeEventEmitterProvider)
}

const logout = async () => {
  if (!safeAuth) return

  await safeAuth.signOut()

  setProvider(null)
  setSafeAuthSignInResponse(null)
}





export default Authkit
