import toast from 'react-hot-toast';

export const copyToClipboard = (str) => {
  navigator.clipboard.writeText(str);
  toast.success("Copied to Clipboard!")
}
 

export const shortenAddress = (address) => {
  return address.slice(0, 4) + " . . . " + address.slice(-5, -1);
}