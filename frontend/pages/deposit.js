import React from 'react';
import Container from '../components/Container';
import Deposit from '../components/Deposit';
import Navbar from '../components/Navbar';
import Withdraw from '../components/Withdraw';

function deposit() {

  return <div className='min-h-screen'>
  <Navbar/>
  <div className='max-w-xl mx-auto container h-full mt-16'>
  <div className='grid gap-4 grid-cols-1  '>
  <div className='col-span-1 w-full'> 
    <Deposit/>
  </div>
  <div className='col-span-1 w-full'> 
    <Withdraw/>
    </div>
  </div>
  </div>
  </div>
}

export default deposit;
