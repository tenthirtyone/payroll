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
  mapping(address => uint256) addressToId;

  uint256 oneMonth = 365 days / 12;

  struct Employee {
    address accountAddress;
    address[] allowedTokens;
    uint256 yearlyUSDSalary;
    uint256 nextPayday;
    bool active;
  }

  modifier onlyOracle() {
    require(msg.sender == _oracle);
    _;
  }

  modifier onlyEmployee() {
    require(_isEmployee[msg.sender]);
    _;
  }

  // If a user is removed/added back we reactive their account.
  function addEmployee(address accountAddress, address[] allowedTokens, uint256 initialYearlyUSDSalary) onlyOwner {
    // Address is new or returning.
    if (!_isEmployee[accountAddress]) {
      Employee memory _employee = Employee({
        accountAddress: accountAddress,
        allowedTokens: allowedTokens,
        yearlyUSDSalary: initialYearlyUSDSalary,
        nextPayday: block.timestamp + oneMonth,
        active: true
      });

      _employees.push(_employee);
      _isEmployee[accountAddress] = true;
    } else {
      uint256 empId = addressToId[accountAddress];
      // Employee must be inactive.
      require(_employees[empId].active == false);
      _employees[empId].allowedTokens = allowedTokens;
      _employees[empId].nextPayday = block.timestamp + oneMonth;
      _employees[empId].active = true;
    }

    _totalPay += initialYearlyUSDSalary;
  }

  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) onlyOwner {
    require(employeeId < _employees.length);
    require(_employees[employeeId].active == true);
    _totalPay -= _employees[employeeId].yearlyUSDSalary;
    _totalPay += yearlyUSDSalary;
    _employees[employeeId].yearlyUSDSalary = yearlyUSDSalary;
  }

  function removeEmployee(uint256 employeeId) onlyOwner {
    require(_employees[employeeId].active == true);
    _totalPay -= _employees[employeeId].yearlyUSDSalary;

    _employees[employeeId].active = false;
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
  function getEmployee(uint256 employeeId) constant returns (address employee, uint256 yearlyUSDSalary, uint256 nextPayday, bool active) {
    Employee storage _employee = _employees[employeeId];
    employee = address(_employee.accountAddress);
    yearlyUSDSalary = uint256(_employee.yearlyUSDSalary);
    nextPayday = uint256(_employee.nextPayday);
    active = bool(_employee.active);
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
   // Remove addressToID, accept empId, check address there.
  function payday() public onlyEmployee {
    uint256 employeeId = addressToId[msg.sender];
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

  // Additional functions
  function getExchangeRate(address token) public view returns (uint256) {
    return _exchangeRates[token];
  }
}
