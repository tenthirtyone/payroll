pragma solidity ^0.4.19;

import './PayrollInterface.sol';
import '../util/Ownable.sol';

contract Payroll is Ownable {
  address _oracle;
  Employee[] public _employees;
  uint256 public _balance;
  mapping(address => uint256) exchangeRates;

  struct Employee {
    address accountAddress;
    address[] allowedTokens;
    uint256 yearlyUSDSalary;
    bool active;
  }

  modifier onlyOracle() {
    require(msg.sender == _oracle);
    _;
  }

  /* OWNER ONLY */
  function addEmployee(address _accountAddress, address[] _allowedTokens, uint256 _initialYearlyUSDSalary) onlyOwner {
    Employee memory _employee = Employee({
      accountAddress: _accountAddress,
      allowedTokens: _allowedTokens,
      yearlyUSDSalary: _initialYearlyUSDSalary,
      active: true
    });

    _employees.push(_employee);
  }

  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) onlyOwner {
    _employees[employeeId].yearlyUSDSalary = yearlyUSDSalary;
  }

  function removeEmployee(uint256 employeeId) onlyOwner {
    _employees[employeeId].active = false;
  }

  function addFunds() payable onlyOwner {
    _balance += msg.value;
  }

  function scapeHatch(address yoinks) onlyOwner {
    selfdestruct(yoinks);
  }

  function getEmployeeCount() constant returns (uint256) {
    return _employees.length;
  }

  function getEmployee(uint256 employeeId) constant returns (address employee, uint256 yearlyUSDSalary, bool active) {
    Employee storage _employee = _employees[employeeId];
    employee = address(_employee.accountAddress);
    yearlyUSDSalary = uint256(_employee.yearlyUSDSalary);
    active = bool(_employee.active);
  }

  function calculatePayrollBurnrate() constant returns (uint256) {
    uint256 rate = 0;

    for (uint256 i = 0; i < _employees.length; i++) {
      if (_employees[i].active == true) {
        uint256 monthlySal = _employees[i].yearlyUSDSalary;
        rate += monthlySal;
      }
    }

    return rate / 12;
  }

  function calculatePayrollRunway() constant returns (uint256) {

  }

  function setExchangeRate(address token, uint256 usdExchangeRate) onlyOracle {

  }

  // Additional function
  function getExchangeRate(address token) public view returns (uint256) {
    return exchangeRates[token];
  }
}
