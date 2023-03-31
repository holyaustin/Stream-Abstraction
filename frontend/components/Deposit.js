import React, { useState } from 'react';
import Moralis from 'moralis';
import toast from 'react-hot-toast';
import Card from './Card'
import Select from './Select';
import { THELS_CONTRACT_ADDRESS, UNI_CONTRACT_ADDRESS } from '../constants/contractAddress';
import ABI, { ERC20_ABI } from '../constants/abi';

const TOKEN_LIST = [
  { name: "🦄UNI", id: 1, value: "UNI", address: UNI_CONTRACT_ADDRESS },
]

function Deposit() {
  const [amount, setAmount] = useState(0.00);
  const [token, setToken] = useState(TOKEN_LIST[0]);
  const [pending, setPending] = useState(false);

  const handleDeposit = () => {
    addCollateral(token.address, amount);
  }

  const addCollateral = async (tokenAddress, amount) => {
    try {
      setPending(true);
      const provider = await Moralis.enableWeb3();
      const signer = provider.getSigner();
      const ethers = Moralis.web3Library;
      const thelsContract = new ethers.Contract(THELS_CONTRACT_ADDRESS, ABI, signer);
      const uniContract = new ethers.Contract(UNI_CONTRACT_ADDRESS, ERC20_ABI, signer);
      const allowance = await uniContract.allowance(await signer.getAddress(), THELS_CONTRACT_ADDRESS);
      if (allowance == 0) {
        let tx = await uniContract.approve(THELS_CONTRACT_ADDRESS, ethers.constants.MaxUint256);
        await tx.wait();
      }
      let depositCollateral = await thelsContract.deposit(tokenAddress, ethers.utils.parseEther(amount));
      await depositCollateral.wait();
      toast.success("Transaction Confirmed 🎉🎉")
      setPending(false);
    } catch (err) {
      console.log(err);
      toast.error(err.message);
      setPending(false);
    }
  }



  return (
    <Card>
      <h1 className='mb-2 text-2xl'>Deposit Collateral</h1>
      <div className='grid gap-4 '>
        <Select value={token} setValue={setToken} list={TOKEN_LIST} />
        <div className='flex  flex-col'>
          <input name="amount" min={0} value={amount} onChange={(e) => setAmount(e.target.value)} className='pl-4' type='number' step="0.10" placeholder="0.00" />
        </div>
        <div className="flex gap-2">
          <button onClick={handleDeposit} disabled={pending} className='bg-emerald-500 hover:bg-emerald-400 active:bg-emerald-600 w-full'>{pending ? "Transaction Pending" : "Deposit"}</button>
        </div>
      </div>
    </Card>);
}

export default Deposit;
