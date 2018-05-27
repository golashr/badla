/**
 * @title TokenContractRegistry by GoSmartChain
 * @dev To act as registry, maintain the addresses of all recognized tokens.
 */
pragma solidity ^0.4.23;
import "./Ownable.sol";

contract TokenContractRegistry is Ownable {

  mapping (bytes32 => address) public registry;
  mapping (bytes32 => bool) public isKnown;

  constructor() public {
    //owner = msg.sender;
  }

  function registerNewToken(bytes32 tokenName, address tokenAddress) public onlyOwner returns (bool) {
    if (isKnown[tokenName])
      revert();

    registry[tokenName] = tokenAddress;
    isKnown[tokenName]  = true;
    return true;
  }

  function getTokenAddress(bytes32 tokenName) public constant returns (address) {
    if (!isKnown[tokenName])
      return 0x0;

    return registry[tokenName];
  }
}
