pragma solidity ^0.4.19;

import './PayrollInterface.sol';
import '../util/Ownable.sol';

contract Payroll is Ownable {
  address _oracle;
  Employee[] public _employees;
  uint256 public _balance;
  mapping(address => uint256) _exchangeRates;
  mapping(address => bool) _isEmployee;
  mapping(address => uint256) addressToId;

  uint256 oneMonth = 30 days;

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

  function addEmployee(address _accountAddress, address[] _allowedTokens, uint256 _initialYearlyUSDSalary) onlyOwner {
    Employee memory _employee = Employee({
      accountAddress: _accountAddress,
      allowedTokens: _allowedTokens,
      yearlyUSDSalary: _initialYearlyUSDSalary,
      nextPayday: block.timestamp + oneMonth,
      active: true
    });

    _employees.push(_employee);
    _isEmployee[_accountAddress] = true;
  }

  function setEmployeeSalary(uint256 employeeId, uint256 yearlyUSDSalary) onlyOwner {
    _employees[employeeId].yearlyUSDSalary = yearlyUSDSalary;
  }

  function removeEmployee(uint256 employeeId) onlyOwner {
    _employees[employeeId].active = false;
    _isEmployee[_employees[employeeId].accountAddress] = false;
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

  function getEmployee(uint256 employeeId) constant returns (address employee, uint256 yearlyUSDSalary, uint256 nextPayday, bool active) {
    Employee storage _employee = _employees[employeeId];
    employee = address(_employee.accountAddress);
    yearlyUSDSalary = uint256(_employee.yearlyUSDSalary);
    nextPayday = uint256(_employee.nextPayday);
    active = bool(_employee.active);
  }

  function calculatePayrollBurnrate() constant returns (uint256) {
    return _totalPay() / 12;
  }
  // Factor in Eth USD exchange rate
  function calculatePayrollRunway() constant returns (uint256) {
    return _balance / (_totalPay() / 365);
  }


  /*
   * Pays out contract balance in Ether based on USD exchange rate
   **/
  function payday() public onlyEmployee {
    uint256 _employeeId = addressToId[msg.sender];
    uint256 nextPayday = _employees[_employeeId].nextPayday;
    uint256 currentDay = block.timestamp;

    require(currentDay >= nextPayday);
    _employees[_employeeId].nextPayday += oneMonth;

    uint256 monthlyPay = _employees[_employeeId].yearlyUSDSalary / 12;
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


  function _totalPay() internal constant returns (uint256) {
    uint256 totalPay = 0;

    for (uint256 i = 0; i < _employees.length; i++) {
      if (_employees[i].active == true) {
        totalPay += _employees[i].yearlyUSDSalary;
      }
    }
    return totalPay;
  }
}
