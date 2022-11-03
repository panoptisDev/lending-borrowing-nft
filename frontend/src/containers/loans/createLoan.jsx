import { Container } from "@chakra-ui/react";
import React from "react";
import { GenericForm } from "./../../components/Form/genericForm";
import { useContractAvailableLiquidity } from "../../data/hooks/contract/useContractAvailableLiquidity";
import { useNft } from "./../../data/context/nftContext";
import { CreateLoanModal } from "./createLoanModal";

export const CreateLoan = () => {
  const { availableLiquidity } = useContractAvailableLiquidity();
  const { selectedNft } = useNft();
    
  const maxAmount =
    selectedNft?.floorPrice > availableLiquidity
      ? availableLiquidity
      : selectedNft?.floorPrice;

  const handleSubmit = (values) => {
    console.log("hello");
    console.log("values", JSON.stringify(values));
  };

  return (
    <Container m={3} mt={10}>
      {!selectedNft && <CreateLoanModal />}

      {selectedNft && (
        <GenericForm handleSubmit={handleSubmit} maxAmount={maxAmount} />
      )}
    </Container>
  );
};