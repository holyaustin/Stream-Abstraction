import { ArrowRightIcon } from '@heroicons/react/outline';
import Link from 'next/link';
import React from 'react';

function HeroSection() {
  return (
    <div className='grid lg:grid-cols-2 mt-12 gap-8 px-4 lg:px-0 items-center justify-center'>
      <div className='flex mb-12  flex-col justify-center'>
        <h1 className='text-4xl lg:text-6xl font-bold mb-6' >
        Stream Abstraction
        </h1>
        <p className='mb-6 text-white-400 max-w-lg lg:text-lg'> Stream Abstraction Makes it possible fpr organisation to stream their payroll with their collateralize crypto assets, and take out loans in the form of streams - without having to sell these assets.</p>
        <div>
        <Link href='/dashboard'>
          <button className='flex gap-2 hover:gap-4 items-center bg-cyan-500 hover:bg-cyan-400 active:bg-cyan-600'>Go to Dashboard
            <ArrowRightIcon className='h-4 w-4' />
          </button>
        </Link>
        </div>

      </div>
      <div>
        <img className='p-4' src='/payroll.jpg' layout='fill' alt='hero-image' />
      </div>

    </div>
  );
}

export default HeroSection;
