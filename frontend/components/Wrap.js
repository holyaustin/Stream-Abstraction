import React, { useState } from 'react';
import Moralis from 'moralis';
import Card from './Card';
import Select from './Select';
import toast from 'react-hot-toast';
import {
  THELS_CONTRACT_ADDRESS
  , USDCX_CONTRACT_ADDRESS
  , USDC_CONTRACT_ADDRESS
} from '../constants/contractAddress';
import ABI, { ERC20_ABI } from '../constants/abi';


const TYPES = [
  { id: 0, name: "Lend", value: 'lend', from: 'USDC', to: 'USDC' },
  { id: 1, name: "Withdraw", value: 'withdraw', from: 'USDCx', to: 'USDC' },
]

function Wrap() {
  const [type, setType] = useState(TYPES[0]);
  const [amount, setAmount] = useState(0);
  const [pending, setPending] = useState(false);


  const convertToUSDCx = async (amt) => {
    try {
      setPending(true)
      const web3Provider = await Moralis.enableWeb3();
      const ethers = Moralis.web3Library;
      const signer = web3Provider.getSigner();
      const max_amt = ethers.constants.MaxUint256;
      //Call thels contract
      const thelsContract = new ethers.Contract(THELS_CONTRACT_ADDRESS, ABI, signer);

      const usdcContract = new ethers.Contract(USDC_CONTRACT_ADDRESS, ERC20_ABI, signer);
      const allowance = await usdcContract.allowance(await signer.getAddress(), THELS_CONTRACT_ADDRESS);
      if (allowance == 0) {
        let tx = await usdcContract.approve(THELS_CONTRACT_ADDRESS, max_amt)
        await tx.wait();
      }
      let convert = await thelsContract.convertToUSDCx(ethers.utils.parseEther(amt));
      await convert.wait();
      console.log(convert);
      toast.success("Transaction Confirmed 🎉🎉")
      setPending(false);
    } catch (err) {
      toast.error(err?.data?.message);
      setPending(false);
      console.log(err);
    }

  }

  const convertToUSDC = async (amt) => {
    try {
      setPending(true)
      const web3Provider = await Moralis.enableWeb3();
      const ethers = Moralis.web3Library;
      const signer = web3Provider.getSigner();
      //Call thels contract
      const thelsContract = new ethers.Contract(THELS_CONTRACT_ADDRESS, ABI, signer);
      let convert = await thelsContract.convertToUSDC(ethers.utils.parseEther(amt));
      await convert.wait();
      toast.success("Transaction Confirmed 🎉🎉")
      setPending(false);
    } catch (err) {
      toast.error(err.message);
      setPending(false);
    }
  }

  const handleWrap = (e) => {
    e.preventDefault();
    if (type.id == 0) {
      convertToUSDCx(amount);
    } else {
      convertToUSDC(amount);
    }
  }

  return (
    <Card>
      <h1 className='text-2xl font-bold mb-4'>Lend / Withdraw Tokens</h1>
      <form onSubmit={handleWrap} className='flex gap-4 flex-col'>
        <Select list={TYPES} value={type} setValue={setType} />
        <input min={0} value={amount} onChange={(e) => setAmount(e.target.value)} type="number" placeholder={`${type.from} amount`} />
        <p>You will {type.value} {amount ? amount : 0} {type.to}</p>
        <button disabled={pending} className='bg-violet-500 hover:bg-violet-400  active:bg-violet-600 shadow-xl'>
          {pending ? "Transaction Pending..." : type.name}
        </button>
      </form>
    </Card>
  )
}

export default Wrap;
