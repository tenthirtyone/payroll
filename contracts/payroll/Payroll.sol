pragma solidity ^0.4.19;

import './PayrollInterface.sol';
import '../util/Ownable.sol';

contract Payroll is Ownable {
  Employee[] public _employees;

  address _oracle;
  uint256 public _balance;
  uint256 public _totalPay;
  mapping(address => uint256) _exchangeRates;
  mapping(address => bool) _isEmployee;

  uint256 oneMonth = 365 days / 12;

  struct Employee {
    uint256 yearlyUSDSalary;
    uint256 nextPayday;
    address accountAddress;
    bool active;
    address[] allowedTokens;
  }

  modifier onlyOracle() {
    require(msg.sender == _oracle);
    _;
  }

  modifier onlyEmployee() {
    require(_isEmployee[msg.sender]);
    _;
  }

  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) onlyOwner {
    require(!_isEmployee[accountAddress]);
    Employee memory _employee = Employee({
      accountAddress: accountAddress,
      allowedTokens: allowedTokens,
      yearlyUSDSalary: initialYearlyUSDSalary,
      nextPayday: block.timestamp + oneMonth,
      active: true
    });

    uint256 _empId = _employees.push(_employee);
    _isEmployee[accountAddress] = true;
    _totalPay += initialYearlyUSDSalary;
  }

  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) onlyOwner {
    require(employeeId < _employees.length);
    _totalPay -= _employees[employeeId].yearlyUSDSalary;
    _totalPay += yearlyUSDSalary;
    _employees[employeeId].yearlyUSDSalary = yearlyUSDSalary;
  }

  function removeEmployee(uint256 employeeId) onlyOwner {
    require(_employees[employeeId].accountAddress != address(0));
    require(_isEmployee[_employees[employeeId].accountAddress] = true);
    _totalPay -= _employees[employeeId].yearlyUSDSalary;
    _isEmployee[_employees[employeeId].accountAddress] = false;
    delete _employees[employeeId];
  }

  function addFunds() payable onlyOwner {
    _balance += msg.value;
  }

  function scapeHatch() onlyOwner {
    selfdestruct(msg.sender);
  }

  // Employee Zero?
  function getEmployeeCount() constant returns (uint256) {
    return _employees.length;
  }

  // Remove tokens, track tokens separately
  function getEmployee(uint256 employeeId) constant returns (address employee, uint256 yearlyUSDSalary, uint256 nextPayday) {
    Employee storage _employee = _employees[employeeId];
    employee = address(_employee.accountAddress);
    yearlyUSDSalary = uint256(_employee.yearlyUSDSalary);
    nextPayday = uint256(_employee.nextPayday);
  }

  function calculatePayrollBurnrate() constant returns (uint256) {
    return _totalPay / 12;
  }

  function calculatePayrollRunway() constant returns (uint256) {
    uint256 ethExchange = _exchangeRates[this];
    return (_balance * ethExchange) / (_totalPay / 365);
  }

  /*
   * Pays out contract balance in Ether based on USD exchange rate
   **/
  function payday(uint256 employeeId) public onlyEmployee {
    require(_employees[employeeId].accountAddress == msg.sender);
    uint256 nextPayday = _employees[employeeId].nextPayday;
    uint256 currentDay = block.timestamp;

    require(currentDay >= nextPayday);
    _employees[employeeId].nextPayday += oneMonth;

    uint256 monthlyPay = _employees[employeeId].yearlyUSDSalary / 12;
    uint256 usdExchange = _exchangeRates[this];

    msg.sender.transfer(monthlyPay / usdExchange);
  }

  function setExchangeRate(address token, uint256 usdExchangeRate) onlyOracle {
    _exchangeRates[token] = usdExchangeRate;
  }

  function isEmployee(address addr) public view returns (bool) {
    return _isEmployee[addr];
  }

  // Additional functions
  function getExchangeRate(address token) public view returns (uint256) {
    return _exchangeRates[token];
  }
}
