import React from 'react';

function Card({ children }) {
  return (
    <div className='p-6 bg-slate-700 bg-opacity-80 shadow-lg drop-shadow-lg border-slate-500 rounded-xl'>
      {children}
    </div>
    )
}

export default Card;
