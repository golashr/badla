pragma solidity ^0.4.23;

import "./ConvertLib.sol";
import "./SafeMath.sol";
import "./Ownable.sol";
import "./ERC20.sol";
import "./StandardToken.sol";

/**
 * @title BadlaToken
 * @dev BadlaToken is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
 contract BadlaToken is StandardToken, Ownable {
   using SafeMath for uint256;

   string public constant name = "Badla Token";
   string public constant symbol = "BADX";
   uint8 public constant decimals = 2;
   uint public constant INITIAL_SUPPLY = 1000000;  // 10,000 tokens times 10 to the decimals

   // how many wei per token                         //10E+18 wei - 1 Ether
   uint256 public constant rate = 10000000000000000; // 0.01 ether per 1 token

   string public site;

   string public why;

   address public wallet;

   // amount of raised money in wei
   uint256 public weiRaised;

   constructor() public {
       totalSupply = INITIAL_SUPPLY;
       balances[msg.sender] = INITIAL_SUPPLY;
       weiRaised = 0;
       owner = msg.sender;
       //wallet = address("0x6f82b145dc42d98ea0110750ad4fd0392a4e2603");
       site = "www.badla.io";
       why = "Buy options, play with money";
   }

   function setSink ( address sink ) public onlyOwner {
      require( sink != 0x0);
      wallet = sink;
   }

   function Site ( string _site ) public onlyOwner {
       site = _site;
   }

   function Why( string _why ) public onlyOwner {
       why = _why;
   }

   /**
    * event for token purchase logging
    * @param purchaser who paid for the tokens
    * @param beneficiary who got the tokens
    * @param value weis paid for purchase
    * @param amount amount of tokens purchased
    */
   event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

   // fallback function can be used to buy tokens
   function () public payable {
     buyTokens(msg.sender);
   }

   // low level token purchase function
   function buyTokens(address beneficiary) public payable {

     require(beneficiary != 0x0);
     require(msg.value > 0);

     //uint256 weiAmount = msg.value;
     uint256 weiAmount = 10;
     // calculate token amount to be created
     uint256 tokens = weiAmount.div(rate);

     // update state
     weiRaised = weiRaised.add(weiAmount);

     totalSupply = totalSupply.add(tokens);
     balances[beneficiary] = balances[beneficiary].add(tokens);
     wallet.transfer(msg.value);

     emit Transfer(0x0, beneficiary, tokens);
     emit TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
   }
 }
