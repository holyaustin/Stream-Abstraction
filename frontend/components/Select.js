import React,{Fragment} from 'react';
import { Listbox,Transition } from '@headlessui/react';
import { SelectorIcon,CheckIcon } from '@heroicons/react/outline';
function Select({value,setValue,list}) {
  // Value -> { name , id , value}
  return (
  <Listbox value={value} onChange={setValue}>
    <div className="relative">
      <Listbox.Button className="relative w-full py-2 pl-4 pr-10 text-left active:scale-[98%] bg-slate-800 active:bg-slate-900 ring-1 ring-slate-500  active:bg-opacity-50 bg-opacity-50 rounded-xl cursor-pointer focus:ring-cyan-500 focus:outline-none focus-visible:ring-2 focus-visible:ring-opacity-75  focus-visible:ring-cyan-500">
        <span className="block truncate">{value.name}</span>
        <span className="absolute inset-y-0 right-0 flex items-center pr-2 pointer-events-none">
          <SelectorIcon
            className="w-5 h-5 text-gray-400"
            aria-hidden="true"
          />
        </span>
      </Listbox.Button>
      <Transition
        as="div"

        leave="transition ease-in duration-100"
        leaveFrom="opacity-100"
        leaveTo="opacity-0"
      >
        <Listbox.Options className="absolute w-full z-10 py-2 mt-2 overflow-auto text-base bg-slate-800 rounded-xl shadow-lg max-h-60 ring-1 ring-black ring-opacity-5 focus:outline-none sm:text-sm">
          {list.map((item) => (
            <Listbox.Option
              key={item.id}
              className={({ active }) =>
                `${active ? 'text-cyan-400' : 'text-slate-200'}
                  cursor-default select-none hover:bg-slate-900 relative py-2 pl-10 pr-4`
              }
              value={item}
            >
              {({ selected, active }) => (
                <>
                  <span
                    className={`${selected ? 'font-medium' : 'font-normal'
                      } block truncate`}
                  >
                    {item.name}
                  </span>
                  {selected ? (
                    <span
                      className={`${active ? 'text-cyan-500' : 'text-cyan-500'
                        }
                        absolute inset-y-0 left-0 flex items-center pl-3`}
                    >
                      <CheckIcon className="w-5 h-5" aria-hidden="true" />
                    </span>
                  ) : null}
                </>
              )}
            </Listbox.Option>
          ))}
        </Listbox.Options>
      </Transition>
    </div>
  </Listbox>
  );
}

export default Select;
