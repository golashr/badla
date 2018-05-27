/**
 * @title ERC20 interface, by OpenZeppelin
 */
pragma solidity ^0.4.23;
import "./Proposal.sol";

contract Ledger {
     address public runnerAddress;                  //Runner address, Contract Owner/Deployer address
     address public protocolWallet;                 //Platform fee collector address
     address public badXTokenAddress;               //BADXToken contract address
     address public tokenRegistrarAddress;          //Token Registrar address

     uint public totalOpCount = 0;                  //Total count of Proposal created
     uint public acceptorFeeAmount = 0.01 ether;    //Platform fee for acceptor

     mapping (address => mapping(uint => address)) private opsPerProposer; //Mapping of Proposer User with index of PR vs ProposalRequests
     mapping (address => uint) private opsCountPerProposer;                //Proposal request count per Proposer User
     mapping (uint => address) private ops;                            //Proposal Requests

     modifier onlyByRunner(){
          require(msg.sender == runnerAddress);
          _;
     }

     constructor() public{
          runnerAddress = msg.sender;
     }

     function setData(address _whereToSendFee,
                            address _badXTokenAddress,
                            address _tokenRegistrarAddress) public{
          runnerAddress = msg.sender;
          protocolWallet = _whereToSendFee;
          badXTokenAddress = _badXTokenAddress;
          tokenRegistrarAddress = _tokenRegistrarAddress;     //TokenContractRegistry
     }

     /// Must be called by Proposer tokens as a collateral
     function createNewProposalRequest(address _proposerAddress,
                                       address _LTokenAddress,
                                       address _RTokenAddress,
                                       int _opType,
                                       int _opDuration) public payable onlyByRunner returns(address out){
          // 1 - send Fee to wherToSendFee
          if(msg.value < acceptorFeeAmount){
               revert();
          }
          protocolWallet.transfer(acceptorFeeAmount);

          // 2 - create new Op
          // will be in state 'WaitingForData'
          out = new Proposal(_proposerAddress, _LTokenAddress, _RTokenAddress, runnerAddress, protocolWallet, badXTokenAddress, _opType, _opDuration);

          // 3 - add to list
          uint currentCount = opsCountPerProposer[msg.sender];
          opsPerProposer[msg.sender][currentCount] = out;
          opsCountPerProposer[msg.sender]++;

          ops[totalOpCount] = out;
          totalOpCount++;
     }
}
