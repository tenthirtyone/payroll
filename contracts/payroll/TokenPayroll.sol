pragma solidity 0.4.19;

import './Payroll.sol';

contract ERC223ReceivingContract {
/**
 * @dev Standard ERC223 function that will handle incoming token transfers.
 *
 * @param from  Token sender address.
 * @param value Amount of tokens.
 * @param data  Transaction metadata.
 */
  function tokenFallback(address from, uint value, bytes data);
}

contract Token {
    mapping (address => uint256) public balanceOf;
    function transfer(address _to, uint256 _value);
}

contract TokenPayroll is Payroll, ERC223ReceivingContract {
  mapping(address => uint256) _tokenBalances; // Internal record keeping
  mapping(address => uint256) _allowedTokens; // Count of employees accepting tokens

  /*
   * Since I loop the allowedTokens later there should be a limit
   * But since it has to loop first, before adding the employee
   * it's probably safe from gas reverts.
   */
  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) onlyOwner {
    // Incremement
    for (uint256 i = 0; i < allowedTokens.length; i++) {
      _allowedTokens[allowedTokens[i]]++;
    }

    super.addEmployee(accountAddress, allowedTokens, initialYearlyUSDSalary);
  }

  function removeEmployee(uint256 employeeId) onlyOwner {
    address[] storage _employeeTokens = _employees[employeeId].allowedTokens;
    // Incremement
    for (uint256 i = 0; i < _employeeTokens.length; i++) {
      _allowedTokens[_employeeTokens[i]]--;
    }

    super.removeEmployee(employeeId);
  }

  function tokenFallback(address from, uint value, bytes data) {
    // Employees must accept this token
    require(_allowedTokens[msg.sender] > 0);
    // msg.sender is the token contract
    _tokenBalances[msg.sender] += value;
  }

  function tokenBalance(address token) constant returns (uint256) {
    return _tokenBalances[token];
  }

  function allowedTokenCount(address token) constant returns (uint256) {
    return  _allowedTokens[token];
  }

  /*
   * I think I'm hit with https://github.com/trufflesuite/truffle/issues/737
   * I tried overloading the payday function. It compiled but truffle won't
   * test it
   */
  function tokenPayday(address token) public onlyEmployee {
    uint256 employeeId = addressToId[msg.sender];
    uint256 nextPayday = _employees[employeeId].nextPayday;
    uint256 currentDay = block.timestamp;

    require(currentDay >= nextPayday);
    _employees[employeeId].nextPayday += oneMonth;

    uint256 monthlyPay = _employees[employeeId].yearlyUSDSalary / 12;
    uint256 tokenExchange = _exchangeRates[token];

    require(tokenExchange > 0);

    uint256 tokenPay = (monthlyPay / tokenExchange);

    // Transfer Token
    _tokenBalances[token] -= tokenPay;
    Token _token = Token(token);
    _token.transfer(msg.sender, tokenPay);
  }

  function calculateTokenPayrollRunway(address token) constant returns (uint256) {
    uint256 exchange = _exchangeRates[token];
    return (_tokenBalances[token] * exchange) / (_totalPay() / 365);
  }

  /*
   * Iterating over employees is not the best way but
   * for a reasonable number of employees / tokens
   * this should be fine
   */
  function tokenScapeHatch() public onlyOwner {
    for (uint256 i = 0; i < _employees.length; i++) {
      address[] _empTokens = _employees[i].allowedTokens;
      for (uint256 j = 0; j < _empTokens.length; j++) {
        uint256 _bal = _tokenBalances[_empTokens[j]];
        if (_bal > 0) {
          _tokenBalances[_empTokens[j]] = 0;
          Token _token = Token(_empTokens[j]);
          _token.transfer(msg.sender, _bal);
        }
      }
    }
    super.scapeHatch();
  }
  /*
   * Without limits/management there is a chance of
   * tokenScapeHatch throwing due to gas limits. This
   * function allows 1:1 withdrawal.
   */
  function tokenScapeHatchSingle(address _addr) public onlyOwner {
    uint256 _bal = _tokenBalances[_addr];
    _tokenBalances[_addr] = 0;
    Token _token = Token(_addr);
    _token.transfer(msg.sender, _bal);
  }
}