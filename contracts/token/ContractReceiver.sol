pragma solidity ^0.4.9;

 /*
 * Contract that is working with ERC223 tokens
 */

 contract ContractReceiver {
  mapping(address => uint256) _tokenBalances; // Internal record keeping
  mapping(address => uint256) _allowedTokens; // Count of employees accepting tokens

  function tokenFallback(address from, uint value, bytes data) {
    // Employees must accept this token
    require(_allowedTokens[msg.sender] > 0);
    // msg.sender is the token contract
    _tokenBalances[msg.sender] += value;
  }
}