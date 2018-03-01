pragma solidity ^0.4.19;

import './payroll/Payroll.sol';

contract ANTPayroll is Payroll {

  function ANTPayroll(address oracleAddress) {
    _oracle = oracleAddress;
  }
}
