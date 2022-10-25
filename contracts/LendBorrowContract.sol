// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LendBorrowContract is Ownable, ReentrancyGuard {
    enum LoanStatus {
        PENDING,
        ACTIVE,
        REPAID
    }

    enum LenderStatus {
        ACTIVE,
        MATURED
    }

    struct Nft {
        address contractAddress;
        uint tokenId;
    }

    struct Loan {
        uint Id;
        uint loanAmount;
        uint fullAmount;  // loan + interest
        uint remainingAmount;
        uint interestAmountPerMonth;
        uint interest;
        address borrower;
        LoanStatus status;
        uint creationTimeInSecs; //stored in unix epoch in sec no datetime in solidity
        uint durationInYears;
      //  Nft nftInfo;
        uint monthlyDeposit;
    }

    struct Lend {
        uint Id;
        address lender;
        uint lendingAmount;
        uint rateOfReturn;
        uint interestEarnedPerDay; // storing return amount per day for now ( something to discuss)
        uint startTimeInSecs;//stored in unix epoch in sec no datetime in solidity
        uint durationInSecs; //stored in unix epoch in sec no datetime in solidity
        LenderStatus status;
        uint latestTimeOfInterestRedeemedInSecs; //stored in unix epoch in second no datetime in solidity
    }

    Loan[] public loans;
    Lend[] public lenders;
   

    uint liquidityAvailable;

    mapping(uint => uint) public borrowingInterestRates;  // could be constant 
    mapping(uint => uint) public lendingReturnRates; // could be constant 

    // emit function for logging 
    event LogLoanCreation(uint indexed _loanId, address indexed _borrower, uint indexed _amount, uint _interest, uint _fullAmount, uint _monthlyDepositAmount, uint _monthlyInterest);
    event LogRetrievedLoan(uint indexed _loanId, address indexed _borrower, uint indexed _amountRetrieved);
    event LogLoanDeposit(uint indexed _loanId, address indexed _borrower, uint _depositAmount, uint _remainingAmount);
    event LogLoanPaid(address indexed _borrower, uint indexed _loanId, uint indexed _depositAmount, uint _remainingAmount);

    event LogLenderCreation(uint indexed _lenderId,address indexed _lender, uint indexed _amount, uint _rateOfReturn, uint _interestEarnedPerDay, uint  _lendingDurationInSecs, uint _startTimeInSecs);
    event LogLenderInterestRedemption(uint indexed _lenderId, address indexed _lender, uint indexed _interestRedeemed, uint _latestTimeOfInterestRedeemed);
    event LogLenderMatured(uint indexed _lenderId, address indexed _lender, uint indexed _lenderAmount, uint _interestNotRedeemed);
    event LogLiquidityAvailable(uint indexed _liquidityAvailable);
    event LogLenderRemainingInterestValue(uint indexed _interestNotRedeemed);

    constructor() {
      liquidityAvailable = 0;
    
      borrowingInterestRates[1] = 10; // 1 year => 10% interest
      borrowingInterestRates[2] = 11; // 2 year => 11% interest

      lendingReturnRates[1] = 5; // 1 year => 5% return
      lendingReturnRates[2] = 6;// 2 year => 6% return
    }

    receive() external payable {}

    // loan methods
    function checkForActiveLoans(address _address) public view returns (bool) {  // internal previously
        for(uint i=0; i < loans.length; i++) {

            if(loans[i].borrower == _address && loans[i].status == LoanStatus.ACTIVE ) {

                return false;
            }
        }
        return true;
    }

    function getLiquidityAvailable() external view returns (uint) {

        return liquidityAvailable;
    }

     // Method to get all Loaners
    function getAllLoaners() external view returns (Loan [] memory) {
        return loans;
    }

    // Method to get all lenders
    function getAllLenders() external view returns (Lend [] memory) {
        return lenders;
    }

    // Method to get all Loaners
    function getUsersLoan() external view returns ( Loan memory) {
        Loan memory result;

        for(uint i=0; i<loans.length; i++) {
            if(loans[i].borrower == msg.sender) {
                result = loans[i];
                break;
            }
        }

        return result;
    }

    // Method to get all lenders
    function getUsersLendings() external view returns (Lend [] memory) {
        Lend[] memory temporary = new Lend[](lenders.length);
        uint counter = 0;
        for(uint i=0; i<lenders.length; i++) {
            if(lenders[i].lender == msg.sender) {
                temporary[counter] = lenders[i];
                counter++;
            }
        }

        Lend[] memory result = new Lend[](counter);
        for(uint i=0; i < counter; i++) {
            result[i] = temporary[i];
        }
        
        return result;
    }

    // to do function to calculate full amount

     function calculateTotalInterestOwedByBorrower(uint _loanAmount, uint _interestRate) internal pure returns (uint) {

       return ((_loanAmount * _interestRate)/100);
    }

    // to do monthly deposit calc
    function calculateMonthlyLoanDeposit(uint _fullAmount, uint _loanDurationInMonths) internal pure returns (uint) {

      return _fullAmount/ _loanDurationInMonths;    
    }

    function createLoan (uint _loanAmount, uint _loanDuration
    //, 
    //address _nftAddress, uint _nftTokenId
    ) external returns (uint) {
        require(_loanAmount <= liquidityAvailable, 'Sorry, we dont have enough liquidity at this moment to fund this loan');
        require(checkForActiveLoans(msg.sender), 'You have an outstanding loan, cannot create a new loan at this moment');

        uint loanId = loans.length;

        uint interestRate = borrowingInterestRates[_loanDuration];

        uint interestAmount = calculateTotalInterestOwedByBorrower(_loanAmount, interestRate);

        uint interestPerMonth = interestAmount/ (_loanDuration * 12);

        uint fullAmount = _loanAmount + interestAmount; 

        uint monthlyDeposit = calculateMonthlyLoanDeposit(fullAmount, _loanDuration * 12);

        loans.push(
            Loan(
                loanId, 
                _loanAmount,
                fullAmount,
                fullAmount,  // initially remaining amount equals fullAmount
                interestPerMonth,
                interestRate, 
                msg.sender,
                LoanStatus.PENDING,
                block.timestamp,
                _loanDuration,
         //       Nft(_nftAddress, _nftTokenId),
                monthlyDeposit
                ));

        emit LogLoanCreation(loanId, msg.sender, _loanAmount, interestRate, fullAmount, monthlyDeposit, interestPerMonth);

        return loanId;
    }

    // method to transfer funds to borrower after loan is created this method will also transfer NFT to the contract ( should be atomic swap in future)

    function transferLoanFunds (uint _loanId) external payable nonReentrant {

        require(msg.sender == loans[_loanId].borrower, "Funds can only be transfered to the borrower of this loan");
        require(loans[_loanId].status == LoanStatus.PENDING , "This loan is already funded");
        uint256 loanAmount = loans[_loanId].loanAmount;
        
        // transfer NFT assuming the owner has approved this smart contract to execute transfer from 
       // ERC721(loans[_loanId].nftInfo.contractAddress).transferFrom(msg.sender, address(this), loans[_loanId].nftInfo.tokenId);
        
        // set the loan as Active
        loans[_loanId].status = LoanStatus.ACTIVE;

        // update liquidity value  
         liquidityAvailable = liquidityAvailable - loans[_loanId].loanAmount;

        // transfer funds to the caller
        (bool success, ) = msg.sender.call{ value:loanAmount }("");

        require(success, "Error: Transfer failed.");

        emit LogRetrievedLoan(_loanId, msg.sender, loanAmount);

        emit LogLiquidityAvailable(liquidityAvailable);

    }

    // method for borrowers to pay entire amount
    function payCompleteLoan(uint _loanId) external payable {

        require(msg.sender == loans[_loanId].borrower, "You must be the assigned borrower for this loan");
        require(msg.value == (loans[_loanId].remainingAmount), "You must pay the full loan amount including interest");
        require(loans[_loanId].status == LoanStatus.ACTIVE, "Loan status must be ACTIVE");

        (bool success, ) = payable(address(this)).call{value: msg.value}("");
        require(success, "Error: Transfer failed.");

        loans[_loanId].status = LoanStatus.REPAID;
        loans[_loanId].remainingAmount = 0;

        liquidityAvailable = liquidityAvailable + loans[_loanId].loanAmount; // add back just principle amount not the interest earned on the loan 
     
        emit LogLoanPaid(msg.sender, _loanId, msg.value, loans[_loanId].remainingAmount);
        emit LogLiquidityAvailable(liquidityAvailable);
    }

    //method for borrowers to to pay monthly deposit
    function payLoanMonthlyDeposit(uint _loanId) external payable 
    {
        require(loans[_loanId].status == LoanStatus.ACTIVE, "Loan status must be Active");
        require(msg.value >= loans[_loanId].monthlyDeposit, "You must deposit amount atleast the monthly deposit amount ");
        require(msg.value <= loans[_loanId].fullAmount, "Your deposit amount exceeds your loan amount");
        require(msg.sender == loans[_loanId].borrower, "You must be the assigned borrower for this loan");
        
        (bool success, ) = payable(address(this)).call{value: msg.value}("");
        require(success, "Error: Transfer failed.");

        loans[_loanId].remainingAmount = loans[_loanId].remainingAmount - msg.value;

        emit LogLoanDeposit(_loanId, msg.sender, msg.value, loans[_loanId].remainingAmount);

        if(loans[_loanId].remainingAmount == 0)
        {
            loans[_loanId].status = LoanStatus.REPAID;

            emit LogLoanPaid(msg.sender, _loanId, msg.value, loans[_loanId].remainingAmount);
        }

        liquidityAvailable = liquidityAvailable + (msg.value - loans[_loanId].interestAmountPerMonth); // update liquidity pool back subtracting the interest per month;

        emit LogLiquidityAvailable(liquidityAvailable);
    }


     // to do function to calculate full amount
    function calculateInterestEarnedPerDay (uint _totalInterestAmount, uint  _lendingDurationInYears) internal pure returns (uint) {

        return ((_totalInterestAmount) /(365 * _lendingDurationInYears)) ;
    }

    // Lender methods
    function createLender(uint _lendingDurationInYears) external payable returns (uint)
    {
        require(msg.value >0, "Please enter a valid amount to lend");

        uint lenderId = lenders.length;
        uint rateOfReturn =   lendingReturnRates[_lendingDurationInYears];
        uint interestAmount = (msg.value * rateOfReturn)/100;
        uint interestEarnedPerDay = calculateInterestEarnedPerDay(interestAmount, _lendingDurationInYears);

        (bool success, ) = payable(address(this)).call{value: msg.value}("");

        uint lendingDurationInSecs = _lendingDurationInYears * 365 * 24 * 60 * 60;
        require(success, "Error: Transfer failed.");

        lenders.push(
            Lend(
            lenderId,
            msg.sender,
            msg.value,
            rateOfReturn,
            interestEarnedPerDay,
            block.timestamp,
            lendingDurationInSecs,
            LenderStatus.ACTIVE,  
            block.timestamp // same as start date of lending
            )
        );

        liquidityAvailable = liquidityAvailable + (msg.value - interestAmount); 

        // Need to log from the lenders array object not from thes so lenders[lenderId]

        emit LogLenderCreation(lenderId, msg.sender, msg.value, lenders[lenderId].rateOfReturn, lenders[lenderId].interestEarnedPerDay, lenders[lenderId].durationInSecs, lenders[lenderId].startTimeInSecs);

        emit LogLiquidityAvailable(liquidityAvailable);

        return lenderId;
    }

    //method  for redeeming interest for lenderers
    
    function redeemLendersInterest(uint _lenderId) external payable nonReentrant {

        require(msg.sender == lenders[_lenderId].lender, "You must be the assigned lender");

        require((lenders[_lenderId].durationInSecs + lenders[_lenderId].startTimeInSecs) >= block.timestamp, "This lending fund has matured, please request to recieve the funds back");

        uint noOfInterestDayAccumulated = (block.timestamp - lenders[_lenderId].latestTimeOfInterestRedeemedInSecs)/ (24 * 60 * 60);

        require(noOfInterestDayAccumulated >= 1, "interest is earned in 24 hours, please check back later");

        uint interestEarned = lenders[_lenderId].interestEarnedPerDay * noOfInterestDayAccumulated;

        // update latest date of interest redeemed 

        lenders[_lenderId].latestTimeOfInterestRedeemedInSecs = lenders[_lenderId].latestTimeOfInterestRedeemedInSecs + ( noOfInterestDayAccumulated * 24 * 60 * 60); // add a day

        //liquidityAvailable = liquidityAvailable - interestEarned; //update liquidity available

        (bool success, ) = msg.sender.call{value: interestEarned}("");

        require(success, "Error: Transfer failed.");

        emit LogLenderInterestRedemption( _lenderId, lenders[_lenderId].lender, interestEarned,  lenders[_lenderId].latestTimeOfInterestRedeemedInSecs); 

        emit LogLiquidityAvailable(liquidityAvailable);

    }

    // method to transfer back locked amount for lenders after the duration is complete

    function retrieveLendersFund(uint _lenderId) external payable nonReentrant{

        require(msg.sender == lenders[_lenderId].lender, "You must be the assigned lender");

        require( lenders[_lenderId].status == LenderStatus.ACTIVE, "lending fund is not active" );

        require((lenders[_lenderId].durationInSecs + lenders[_lenderId].startTimeInSecs) <= block.timestamp, "lending fund is not matured yet" );


        uint interestNotRedeemed = (lenders[_lenderId].interestEarnedPerDay * (lenders[_lenderId].durationInSecs - lenders[_lenderId].latestTimeOfInterestRedeemedInSecs)/ (24 * 60 * 60));

       //  uint remainingAmount = lenders[_lenderId].lendingAmount + interestNotRedeemed;

        lenders[_lenderId].status = LenderStatus.MATURED;
        
        liquidityAvailable = liquidityAvailable - lenders[_lenderId].lendingAmount; //update liquidity available 

        uint totalAmountToRefund = interestNotRedeemed + lenders[_lenderId].lendingAmount;

        (bool success, ) = msg.sender.call{value: totalAmountToRefund}("");

        require(success, "Error: Transfer failed."); 

        emit LogLiquidityAvailable(liquidityAvailable);

        emit LogLenderMatured(_lenderId, lenders[_lenderId].lender, lenders[_lenderId].lendingAmount, interestNotRedeemed);

    }

}