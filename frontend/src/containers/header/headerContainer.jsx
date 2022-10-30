import { useNavigate } from "react-router";
import { useAccount } from "wagmi";
import { useWallet } from "./../../data/context/walletContext";
import { useEffect } from "react";
import abi from "./../../contracts/LendBorrower.json";
import { ethers } from "ethers";

export const HeaderContainer = () => {
  const navigation = useNavigate();
  const { address } = useAccount();
  const { walletType, setWalletType } = useWallet();

  const contractAbi = abi.abi;
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const lenderborrowerContract = new ethers.Contract(
    "0xB358B0851Feb9853Cf2D016E5c2653A847659098",
    contractAbi,
    provider
  );

  useEffect(() => {
    if (!address) {
      return;
    }

    const getAccountType = async () => {
      const accountType = await lenderborrowerContract.getAccountType(address);

      setWalletType(accountType);
    };

    getAccountType().catch(console.error);
  }, [address]);

  useEffect(() => {
    if(!walletType)
      return;
      
    if (walletType === "InActive") {
      navigation("/signup");
      return;
    }

    navigation(`/`);
    return;
  }, [walletType]);

  return <div></div>;
};