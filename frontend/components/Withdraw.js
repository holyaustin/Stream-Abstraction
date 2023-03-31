import React, { useState } from 'react';
import Moralis from 'moralis';

import Card from './Card'
import Select from './Select';
import { THELS_CONTRACT_ADDRESS, UNI_CONTRACT_ADDRESS } from '../constants/contractAddress';
import ABI from '../constants/abi';
import toast from 'react-hot-toast';

const TOKEN_LIST = [
  { name: "🦄UNI", id: 1, value: "UNI", address: UNI_CONTRACT_ADDRESS },
]

function Withdraw() {
  const [amount, setAmount] = useState(0.00);
  const [token, setToken] = useState(TOKEN_LIST[0]);
  const [pending, setPending] = useState(false);
  const handleWithdraw = () => {
    withdraw(token.address, amount);
  }


  const withdraw = async (tokenAddress, amount) => {
    try {
      setPending(true);
      const provider = await Moralis.enableWeb3();
      const signer = provider.getSigner();
      const ethers = Moralis.web3Library;
      const thelsContract = new ethers.Contract(THELS_CONTRACT_ADDRESS, ABI, signer);
      let withdrawCollateral = await thelsContract.withdraw(tokenAddress, ethers.utils.parseEther(amount));
      await withdrawCollateral.wait();
      toast.success("Transaction Confirmed 🎉🎉")
      setPending(false);
    } catch (err) {
      toast.error(err.message);
      setPending(false);
      console.log(err);
    }
  }

  return (
    <Card>
      <h1 className='mb-2 text-2xl'>Withdraw</h1>
      <div className='grid gap-4 '>
        <Select value={token} setValue={setToken} list={TOKEN_LIST} />
        <div className='flex  flex-col'>
          <input name="amount" min={0} value={amount} onChange={(e) => setAmount(e.target.value)} className='pl-8 ' type='number' step="0.10" placeholder="0.00" />
        </div>
        <div className="flex gap-2">
          <button onClick={handleWithdraw} disabled={pending} className='bg-violet-500 hover:bg-violet-400 active:bg-violet-600 w-full'>{pending ? "Transaction Pending..." : "Withdraw"}</button>
        </div>
      </div>
    </Card>)
    ;
}

export default Withdraw;
