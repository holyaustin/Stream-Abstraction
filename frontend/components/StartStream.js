import React, { useState, Fragment, useRef, useEffect } from 'react';
import Card from './Card';
import toast from 'react-hot-toast'
import Select from './Select';
import Moralis from "moralis";
import { THELS_CONTRACT_ADDRESS } from '../constants/contractAddress';
import ABI from '../constants/abi';


const durations = [
  { id: 1, name: '/ day', inSeconds: 60 * 60 * 24 },
  { id: 2, name: '/ week', inSeconds: 60 * 60 * 24 * 7 },
  { id: 3, name: '/ month', inSeconds: 60 * 60 * 24 * 30 },
  { id: 4, name: '/ year', inSeconds: 60 * 60 * 24 * 365 },
]

function StartStream() {
  const [selectedDuration, setSelectedDuration] = useState(durations[0]);
  const [amountPerSecond, setAmountPerSecond] = useState(0);
  const [amount, setAmount] = useState(0);
  const [endTime, setEndTime] = useState((new Date()).getDate());

  const handleSubmit = (e) => {
    e.preventDefault();
    const receiverAddress = e.target[0].value;
    startNewStream(receiverAddress,amountPerSecond,endTime);
  }

  const startNewStream = async (receiver, flowRate, endTime) => {
    try{
      const provider = await Moralis.enableWeb3();
      const signer = provider.getSigner();
      const ethers = Moralis.web3Library;
      const thelsContract = new ethers.Contract(THELS_CONTRACT_ADDRESS, ABI, signer);
      const tx = await thelsContract.startStream(receiver,ethers.utils.parseEther(flowRate),getUnixTimestamp(endTime));
      await tx.wait();
      console.log(tx)
    } catch(err){
      console.log(err);
      toast.error(err.message);
    }
  }



  const getUnixTimestamp = (time)=>{
    return Math.round(Date.parse(time) / 1000);
  } 
  useEffect(() => {
    const durationInSeconds = selectedDuration.inSeconds;
    setAmountPerSecond((amount / durationInSeconds).toFixed(5));
  }, [amount, selectedDuration])

  return(
  <Card>
    <h1 className='text-2xl font-bold mb-4'>Start a new stream</h1>
    <form onSubmit={handleSubmit} className='grid grid-cols-2 gap-4'>
      <div className='flex col-span-2 flex-col'>
        <input name='receiver_address' placeholder="Receiver's address " type="text" />
      </div>
      <div className='flex grid-cols-1 flex-col relative'>
   
        <input name="amount" value={amount} onChange={(e) => setAmount(e.target.value)} className='pl-4 ' type='number' step="0.10" placeholder="0.00" />
      </div>
      <div>
        <Select value={selectedDuration} setValue={setSelectedDuration} list={durations} />
      </div>
      <div className='col-span-2'>
      <label htmlFor="endTime" className='text-xs text-gray-400 pl-2 font-medium mb-1 mt-2'>Enter end time</label>
        <input name="endTime" type='date' placeholder="Enter End time " value={endTime}
          onChange={(e) => {
            setEndTime(e.target.value)
          }}
          className='pl-4 w-full' step="0.10" />
      </div>
      <h1 className='text-2xl col-span-2 font-bold'>$ {amountPerSecond}  <span className='text-sm font-normal relative -top-1 text-gray-300'> / second </span></h1>
      <button type="submit" className='whitespace-nowrap col-span-2 text-center bg-emerald-500 hover:bg-emerald-400 active:bg-emerald-600'>Start Streaming</button>
    </form >
  </Card >);
}

export default StartStream;
