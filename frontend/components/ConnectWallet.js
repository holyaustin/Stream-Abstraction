import React, { useEffect, useState } from 'react';
import { useMoralis } from 'react-moralis';
import { DuplicateIcon } from '@heroicons/react/outline'
import { shortenAddress ,copyToClipboard } from '../utils/utils';
import toast from 'react-hot-toast';


const btnStyle = "bg-cyan-500 hover:shadow-2xl cursor-pointer font-display transition ease-out duration-300 py-2 px-4  rounded-xl  hover:bg-cyan-400 active:bg-cyan-600 text-white flex gap-2 items-center"

const ConnectWallet = () => {
  const [walletAddress, setWalletAddress] = useState('');
  const { authenticate, isAuthenticated, user } = useMoralis();

  useEffect(() => {
    if(isAuthenticated){
      setWalletAddress(user.get('ethAddress'));
    }
  }, [user]);

  if (!isAuthenticated) {
    return (
      <button onClick={() => authenticate({onSuccess:()=>toast.success("Wallet Connected Successfully"),onError:()=>toast.error("Error connecting to wallet")})} className={btnStyle}>
        Connect Wallet
      </button>
    );
  }
  return (
    <div as="div"  className={btnStyle}>
      {shortenAddress(walletAddress)}
      <DuplicateIcon onClick={()=>copyToClipboard(walletAddress)} className='w-5 h-5 cursor-pointer hover:scale-110 transition duration-100 ease-out' />
    </div>
  )
}

export default ConnectWallet;
