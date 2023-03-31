import React, { useState } from 'react';
import Moralis from 'moralis';
import Card from './Card';
import { THELS_CONTRACT_ADDRESS } from '../constants/contractAddress';
import ABI from "../constants/abi"

function StopStream() {
  const [address, setAddress] = useState('');
  const [pending,setPending] = useState(false)

  const _stopStream = async () => {
    try {
      setPending(true);
      const provider = await Moralis.enableWeb3();
      const signer = provider.getSigner();
      const ethers = Moralis.web3Library;
      const thelsContract = new ethers.Contract(THELS_CONTRACT_ADDRESS, ABI, signer);
      const tx = await thelsContract.stopStream(address.toString());
      await tx.wait();
      toast.success("Transaction Confirmed 🎉🎉")
      setPending(false);
    } catch (err) {
      toast.error(err.message);
      setPending(false);
      console.log(err);
    }
  }

  return <Card>
    <h1 className='text-2xl font-bold mb-4'>Stop Stream</h1>
    <div className='flex flex-col gap-4' >
      <input type="text" placeholder="Enter Receiver's Address" value={address} onChange={e => setAddress(e.target.value)} />
      <button onClick={_stopStream} disabled={pending} className='bg-rose-400'>{pending ? "Transaction Pending " : "Stop Stream"}</button>
    </div>
  </Card>;
}

export default StopStream;
