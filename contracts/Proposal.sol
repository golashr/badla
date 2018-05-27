pragma solidity ^0.4.23;

import "./SafeMath.sol";
import "./ERC20Basic.sol";
import "./BadlaToken.sol";

/*
 * Proposal Contract will be created for each loan request.
 */
 contract Proposal {
      /* Different states of Proposal contract */
      enum OpState {
           ProposalCreated,    //Initial state
           WaitingForAccepter, //Waiting for Acceptor to come
           Cancelled,          //When proposal is cancelled
           ProposalAccepted,   //When acceptor has accepted the proposal
           ProposalLive,       //When collateral ERC20 tokens received from acceptor, now waiting for proposer to give ERC20 token loan in exchange
           WaitingForPayback,  //When loan is given by the Proposer and Acceptor received it
           Default,            //When loan defaulted by Acceptor
           Finished            //When loan paid in full by Acceptor and finished
      }

      /* Different Duration of Proposal contract */
      enum OpDuration {
           Two,                  //2 days duration
           Seven,                  //7 days duration
           Fourteen,                 //14 days duration
           Thirty                  //30 days duration
      }

      /* Different Type of Proposal contract */
      enum OpType {
           BuyAndSellBack,     //BuyAndSellBack type
           SellAndBuyBack      //SellAndBuyBack type
      }

      using SafeMath for uint256;                                            //SafeMath Library using for uint256
      address public creatorAddress            = 0x0;                        //Creator of this contract, always be Ledger's address
      address public runnerAddress             = 0x0;                        //Who deployed Parent Ledger
      address public protocolWallet            = 0x0;                        //Platform fee will be sent to this wallet address
      uint public platformFeeAmount            = 0.01 ether;                 //Proposer's platform fee
      address public platformFeeTokenAddress   = 0x0;                        //BADX token address, will be static and set during deployment

      OpState public currentState              = OpState.ProposalCreated;    //Initial state ProposalCreated
      OpDuration public proposalDuration       = OpDuration.Seven;               //Initial Duration 7 days
      OpType public proposalType               = OpType.BuyAndSellBack;      //Initial Duration 7 days

      /* These variables will be set by Proposer:  L <--> R (L Token from Proposer and R Token from Acceptor)*/
      address public proposerAddress           = 0x0;                        //Proposer Address
      string public pairName                   = "";                         //Name of the Ledger in Token1VsToken2

      string public oraclizeInfolink           = "";                         //Optional, Oraclise link to get LvsR ratio live
      address public tokenSmartContractaddressL= 0x0;                        //Loan ERC20 Token's contract address - Proposer's token
      uint public amountTokenLInitial          = 0;                          //Amount of WETH token for acceptor, once acceptor accepts the proposal
      address public tokenSmartContractaddressR= 0x0;                        //Collateral ERC20 Token's contract address - Acceptor's token
      uint public amountTokenRInitial          = 0;                          //Amount of collateral token if acceptor accepts the Proposer
      uint public amountTokenRToReturn         = 0;                          //Amount of collateral token to retrieve from the Proposer after the duration
      uint public proposalStartTime            = 0;                          //Holds the startTime of the transaction when options is bought
      uint public proposalExpiryTime           = 0;                          //Holds the expiryTime afterwards, propsoal is not available for acceptance

      /* These variables will be set when Acceptor is found */
      address public acceptorAddress           = 0x0;                        //Acceptor's wallet address
      uint public noOfUnits                    = 0;                          //No of options are being accepted by acceptor
      uint public contractStartTime            = 0;                          //UTC time when acceptor accepted the proposal
      uint public contractSettlementTime       = 0;                          //UTC time when transaction should get completed as per the proposal

      /* Constants Methods: */
      function getCreatorAddress() public constant returns(address){ return creatorAddress; }
      function getLedgerParentAddress() public constant returns(address){ return runnerAddress; }
      function getProtocolWalletAddress() public constant returns(address){ return protocolWallet; }
      function getOpState() public constant returns(OpState){ return currentState; }
      function getOpDuration() public constant returns(OpDuration){ return proposalDuration; }
      function getOpType() public constant returns(OpType){ return proposalType; }
      function getProposerAddress() public constant returns(address){ return proposerAddress; }
      function getPairName() public constant returns(string){ return pairName; }
      function getOraclizeInfoLink() public constant returns(string){ return oraclizeInfolink; }
      function getTokenLAddress() public constant returns(address){ return tokenSmartContractaddressL; }
      function getTokenLInitial() public constant returns(uint){ return amountTokenLInitial; }
      function getTokenRAddress() public constant returns(address){ return tokenSmartContractaddressR; }
      function getTokenRInitial() public constant returns(uint){ return amountTokenRInitial; }
      function getTokenRToReturn() public constant returns(uint){ return amountTokenRToReturn; }
      function getProposalStartTime() public constant returns(uint){ return proposalStartTime; }
      function getProposalExpiryTime() public constant returns(uint){ return proposalExpiryTime; }
      function getAcceptorAddress() public constant returns(address){ return acceptorAddress; }
      function getContractStartTime() public constant returns(uint){ return contractStartTime; }
      function getContractSettlementTime() public constant returns(uint){ return contractSettlementTime; }

      modifier onlyByRunner(){
           require(msg.sender == runnerAddress);
           _;
      }

      modifier byRunnerOrProposer(){
           require(msg.sender == runnerAddress || msg.sender == proposerAddress);
           _;
      }

      modifier byRunnerOrAcceptor(){
           require(msg.sender == runnerAddress || msg.sender == acceptorAddress);
           _;
      }

      modifier byRunnerOrProposerAcceptor(){
           require(msg.sender == runnerAddress || msg.sender == proposerAddress || msg.sender == acceptorAddress);
           _;
      }

      modifier onlyByProposer(){
           require(msg.sender == proposerAddress);
           _;
      }

      modifier onlyInState(OpState state){
           require(currentState == state);
           _;
      }

      constructor(address _proposer,
                  address _tokenSmartContractaddressL,
                  address _tokenSmartContractaddressR,
                  address _runnerAddress,
                  address _protocolWallet,
                  address _platformFeeTokenAddress,
                  int _opType,
                  int _opDuration) public {

           runnerAddress = _runnerAddress;
           protocolWallet = _protocolWallet;
           platformFeeTokenAddress = _platformFeeTokenAddress;
           tokenSmartContractaddressL = _tokenSmartContractaddressL;
           tokenSmartContractaddressR = _tokenSmartContractaddressR;

           proposerAddress = _proposer;

           // state: ProposalCreated
           currentState = OpState.ProposalCreated;

           // type: BuyAndSellBack or SellAndBuyBack
           if (_opType == 0){
                proposalType = OpType.BuyAndSellBack;
           } else if(_opType == 1){
                proposalType = OpType.SellAndBuyBack;
           } else {
                revert();
           }

           // duration: 2, 7, 14 or 30 days
           if (_opDuration == 0){
                proposalDuration = OpDuration.Two;
           } else if(_opDuration == 1){
                proposalDuration = OpDuration.Seven;
           } else if(_opDuration == 2){
                proposalDuration = OpDuration.Fourteen;
           } else if(_opDuration == 3){
                proposalDuration = OpDuration.Thirty;
           } else {
                revert();
           }
      }

      function setData(string _pairName, string _oraclizelink,
                       uint _amountTokenLInitial,
                       uint _amountTokenRInitial,
                       uint _amountTokenRToReturn,
                       uint _startTime, uint _expiryTime) public
                       byRunnerOrProposer onlyInState(OpState.ProposalCreated)
      {
           pairName = _pairName;
           oraclizeInfolink = _oraclizelink;

           amountTokenLInitial = _amountTokenLInitial;
           amountTokenRInitial = _amountTokenRInitial;
           amountTokenRToReturn= _amountTokenRToReturn;

           proposalStartTime   = _startTime;
           proposalExpiryTime  = _expiryTime;

           currentState = OpState.WaitingForAccepter;
      }

      function cancelProposal() public byRunnerOrProposer {
           // 1 - check current state
           if((currentState != OpState.ProposalCreated) && (currentState != OpState.WaitingForAccepter))
                revert();

           currentState = OpState.Cancelled;
           tokenSmartContractaddressR = 0x0;

           pairName = "";
           tokenSmartContractaddressL = 0x0;
           tokenSmartContractaddressR = 0x0;
           oraclizeInfolink = "";

           amountTokenLInitial = 0;
           amountTokenRInitial = 0;
           amountTokenRToReturn= 0;

           proposalStartTime   = 0;
           proposalExpiryTime  = 0;
      }

      //Acceptor has accepted the proposal before its expir
      function acceptProposal(address _acceptorAddress, uint _noOfUnits,
                                     uint _contractStartTime, uint _contractSettlementTime ) public
                                     byRunnerOrAcceptor
                                     onlyInState(OpState.WaitingForAccepter){
           // 1 - check current state
           if((currentState != OpState.ProposalCreated) && (currentState != OpState.WaitingForAccepter))
                revert();

           acceptorAddress       = _acceptorAddress;
           noOfUnits             = _noOfUnits;

           contractStartTime     = _contractStartTime;
           contractSettlementTime= _contractSettlementTime;

           //Set the state right!
           currentState          = OpState.ProposalAccepted;
      }

      //Will be called when Acceptor has given its collateral and locked in the contract
      function lockInCollateralProposal() public
               onlyByRunner onlyInState(OpState.ProposalAccepted){

           //Set the state right!
           currentState = OpState.ProposalLive;

           //if(msg.value < amountTokenRInitial.add(lenderFeeAmount)){
             //   revert();
           //}

           // send platform fee first
           protocolWallet.transfer(platformFeeAmount);

           StandardToken tokenR = StandardToken(tokenSmartContractaddressR);
           tokenR.transferFrom(acceptorAddress,runnerAddress, amountTokenRInitial);

           // if you sent this -> you are the lender
           //lender = msg.sender;

           // ETH is sent to borrower in full
           // Tokens are kept inside of this contract
           //borrower.transfer(amountTokenRInitial);
           contractStartTime = now;
      }

      // Should check if tokens are 'available' in proposer account
      function checkTokensL() onlyByRunner onlyInState(OpState.ProposalCreated) public view returns(bool){

           StandardToken BADX = StandardToken(platformFeeTokenAddress);
           uint tokenBalance = BADX.balanceOf(proposerAddress);

           if(tokenBalance < platformFeeAmount){
             StandardToken tokenL = StandardToken(tokenSmartContractaddressL);
             tokenBalance = tokenL.balanceOf(proposerAddress);
             if(tokenBalance < amountTokenLInitial)
                 revert(); //Proposer does not have as many tokens in his/her account
           }else
               revert(); //Proposer does not have as many tokens in his/her account

         return true; //Proposer has those many tokens in his/her account
      }

      // Should check if tokens are available' in acceptor account
      function checkTokensR() onlyByRunner onlyInState(OpState.ProposalAccepted) public view {

          StandardToken BADX = StandardToken(platformFeeTokenAddress);
          uint tokenBalance = BADX.balanceOf(proposerAddress);

          if(tokenBalance < platformFeeAmount){
            StandardToken tokenR = StandardToken(tokenSmartContractaddressR);
            tokenBalance = tokenR.balanceOf(proposerAddress);
            if(tokenBalance < amountTokenRInitial)
                revert(); //acceptor does not have as many tokens in his/her account
          }else
              revert(); //acceptor does not have as many tokens in his/her account

        return; //acceptor has those many tokens in his/her account
      }

      // This function is called when someone sends money to this contract directly.
      //
      // If someone is sending at least 'amountTokenLInitial' amount of money in WaitingForProposer state
      // -> then it means it's a Proposer.
      //
      // If someone is sending at least 'amountTokenRInitial' amount of money in WaitingForPayback state
      // -> then it means it's a Acceptor returning money back.
      function() public payable {
           if(currentState == OpState.ProposalCreated){
                waitingForProposer();
           } if(currentState == OpState.WaitingForAccepter){
                waitingForAccepter();
           } else if(currentState == OpState.WaitingForPayback){
                waitingForPayback();
           } else {
                revert(); //In any other state, do not accept Ethers
           }
      }

     function waitingForProposer() public payable onlyByRunner onlyInState(OpState.ProposalCreated){
           //if(msg.value < amountTokenLInitial.add(lenderFeeAmount)){
             //   revert();
           //}

           // send platform fee first
           protocolWallet.transfer(platformFeeAmount);

           // if you sent this -> you are the lender
           //address addressLedger = msg.sender;
           //ledger =

           // ETH is sent to borrower in full
           // Tokens are kept inside of this contract
           //borrower.transfer(amountTokenRInitial);

           StandardToken tokenF = StandardToken(platformFeeTokenAddress);
           tokenF.approve(runnerAddress,platformFeeAmount);

           StandardToken tokenL = StandardToken(tokenSmartContractaddressL);
           tokenL.approve(runnerAddress,amountTokenLInitial);

           currentState = OpState.WaitingForPayback;

           proposalStartTime = now;
      }

      function waitingForAccepter() public payable onlyByRunner onlyInState(OpState.WaitingForAccepter){
           //if(msg.value < amountTokenLInitial.add(lenderFeeAmount)){
             //   revert();
           //}

           // send platform fee first
           protocolWallet.transfer(platformFeeAmount);

           // if you sent this -> you are the lender
           //ledger = msg.sender;

           // ETH is sent to borrower in full
           // Tokens are kept inside of this contract
           //borrower.transfer(amountTokenRInitial);

           StandardToken tokenP = StandardToken(platformFeeTokenAddress);
           tokenP.approve(runnerAddress,platformFeeAmount);

           StandardToken tokenL = StandardToken(tokenSmartContractaddressL);
           tokenL.approve(runnerAddress,amountTokenLInitial);

           currentState = OpState.WaitingForPayback;

           contractStartTime = now;
      }

      function waitingForPayback() public payable onlyByRunner onlyInState(OpState.WaitingForPayback){
           //if(msg.value < amountTokenLInitial.add(lenderFeeAmount)){
             //   revert();
           //}

           // send platform fee first
           protocolWallet.transfer(platformFeeAmount);

           // if you sent this -> you are the lender
           //ledger = msg.sender;

           // ETH is sent to borrower in full
           // Tokens are kept inside of this contract
           //borrower.transfer(amountTokenRInitial);

           StandardToken tokenP = StandardToken(platformFeeTokenAddress);
           tokenP.approve(runnerAddress,platformFeeAmount);

           StandardToken tokenL = StandardToken(tokenSmartContractaddressL);
           tokenL.approve(runnerAddress,amountTokenLInitial);

           currentState = OpState.WaitingForPayback;

           contractStartTime = now;
      }

      // If no lenders -> borrower can cancel the LR
      function returnRTokens() public onlyByRunner onlyInState(OpState.WaitingForPayback){
           // tokens are released back to borrower
           releaseToAcceptorDuringOrAfterTransaction();
           currentState = OpState.Finished;
      }

      // After time has passed but lender hasn't returned the loan -> move tokens to lender
      // anyone can call this (not only the lender)
      function requestDefault() public onlyByRunner onlyInState(OpState.WaitingForPayback){

           uint days_to_lend = 0;
           if(proposalDuration == OpDuration.Two){
               days_to_lend = 2;
           } else if(proposalDuration == OpDuration.Seven){
               days_to_lend = 7;
           } else if(proposalDuration == OpDuration.Fourteen){
               days_to_lend = 14;
           } else if(proposalDuration == OpDuration.Thirty) {
               days_to_lend = 30;
           } else {
               revert(); //In any other state, do not accept Ethers
           }

           if(now < (contractStartTime + days_to_lend * 1 days)){
                revert();
           }

           releaseToProposerInDefault(); // tokens are released to the lender
           // ledger.addRepTokens(lender,amountTokenRInitial); // Only Proposer get Reputation tokens
           currentState = OpState.Default;
      }

      function releaseToProposerBeforeTransaction() public onlyByRunner onlyInState(OpState.WaitingForAccepter) {

           if(proposalType == OpType.BuyAndSellBack){
                StandardToken token = StandardToken(tokenSmartContractaddressL);
                //uint tokenBalance = token.balanceOf(this);
                token.transferFrom(runnerAddress,proposerAddress,amountTokenLInitial);
           }
           currentState = OpState.Cancelled;
           //ledger.burnRepTokens(borrower);
      }

      function releaseToProposerInDefault() public onlyByRunner onlyInState(OpState.WaitingForPayback) {

           if(proposalType == OpType.BuyAndSellBack){
                StandardToken token = StandardToken(tokenSmartContractaddressR);
                //uint tokenBalance = token.balanceOf(this);
                token.transferFrom(runnerAddress,proposerAddress,amountTokenRInitial);
           }
           //ledger.burnRepTokens(borrower);
      }

      function releaseToProposerDuringOrAfterTransaction() public onlyByRunner onlyInState(OpState.WaitingForPayback) {

           if(proposalType == OpType.BuyAndSellBack){
                StandardToken tokenL = StandardToken(tokenSmartContractaddressL);
                //uint tokenBalance = token.balanceOf(this);
                tokenL.transferFrom(runnerAddress,proposerAddress,amountTokenLInitial);

                //Need to transfer  tokens to Proposer as his/her profit!!
                uint profit = amountTokenRInitial.sub(amountTokenRToReturn);
                StandardToken tokenR = StandardToken(tokenSmartContractaddressR);
                //uint tokenBalance = token.balanceOf(this);
                tokenR.transferFrom(runnerAddress,proposerAddress,profit); //Profit is transfered to Proposer
           }
           //ledger.burnRepTokens(borrower);
      }

      function releaseToAcceptorDuringOrAfterTransaction() public onlyByRunner onlyInState(OpState.WaitingForPayback) {
           if(proposalType == OpType.BuyAndSellBack){
                StandardToken token = StandardToken(tokenSmartContractaddressR);
                //uint tokenBalance = token.balanceOf(this);
                token.transferFrom(runnerAddress,acceptorAddress,amountTokenRToReturn);
           }
      }
 }
