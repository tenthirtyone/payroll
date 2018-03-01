pragma solidity ^0.4.19;

import './payroll/TokenPayroll.sol';

contract ANTTokenPayroll is TokenPayroll {

  function ANTTokenPayroll(address oracleAddress) {
    _oracle = oracleAddress;
  }
}
