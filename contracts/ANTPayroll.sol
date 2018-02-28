pragma solidity ^0.4.19;

import './payroll/TokenPayroll.sol';

contract ANTPayroll is TokenPayroll {

  function ANTPayroll(address oracleAddress) {
    _oracle = oracleAddress;
  }
}
