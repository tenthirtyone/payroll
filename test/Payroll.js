import { increaseTimeTo, duration } from './helpers/increaseTime';
import assertRevert, { assertError } from './helpers/assertRevert'

const BigNumber = web3.BigNumber
const ANTPayroll = artifacts.require('ANTPayroll')
const ANTTokenPayroll = artifacts.require('ANTTokenPayroll')
const TokenERC20 = artifacts.require('TokenERC20')

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

const expect = require('chai').expect

contract('Payroll Test', async (accounts) => {
  await increaseTimeTo(Date.now());
  let payroll = null;
  let tokenPayroll = null;

  let token1 = await TokenERC20.new(10 * 10e28, 'USD Token', 'USD');
  let token2 = await TokenERC20.new(10 * 10e28, 'Token 2', 'Tkn2');
  let token3 = await TokenERC20.new(10 * 10e28, 'Token 3', 'Tkn3');

  const oneContractMonth = 2628000;

  const [creator, user, anotherUser, oracle, mallory] = accounts

  // Token USD Exchange Rates
  const ethExchange  = 1000; // 1000 USD = 1 Eth
  const tknExchange1 = 1;
  const tknExchange2 = 10;
  const tknExchange3 = 100;

  const seedFund = 1000 * 10e18; // Eth seed fund
  const yearlySalary = 100 * 10e18; // 100 Salary in Eth

  const fromOracle = {
    from: oracle
  };

  beforeEach(async () => {
    payroll = await ANTPayroll.new(oracle);
    tokenPayroll = await ANTTokenPayroll.new(oracle);

    await payroll.addEmployee(creator, [token1.address, token2.address], yearlySalary);

    await payroll.setExchangeRate(payroll.address, ethExchange, fromOracle);
    await payroll.setExchangeRate(token1.address, tknExchange1, fromOracle);
    await payroll.setExchangeRate(token2.address, tknExchange2, fromOracle);
    await payroll.setExchangeRate(token3.address, tknExchange3, fromOracle);
  })

  describe('Owner Functions', () => {
    it('Adds a new employee', async () => {
      const emp = await payroll._employees(0);

      emp[2].should.be.equal(creator);
    })
    it('Total pay is new employee pay', async () => {
      const totalPay = await payroll._totalPay();

      totalPay.should.be.bignumber.equal(yearlySalary);
    })
    it('Checks if the employee exists', async () => {
      const exists = await payroll.isEmployee(creator);
      exists.should.be.equal(true);
    })
    it('Sets an employee salary', async () => {
      await payroll.setEmployeeSalary(0, 5000);

      await assertRevert(payroll.setEmployeeSalary(100, 5000));

      const emp = await payroll.getEmployee(0);
      emp[1].should.be.bignumber.equal(5000);

      const totalPay = await payroll._totalPay();
      totalPay.should.be.bignumber.equal(5000);
    })
    it('Removes an employee', async () => {
      await payroll.removeEmployee(0);

      const emp = await payroll.getEmployee(0);

      emp[1].should.be.bignumber.equal(0);

      const exists = await payroll.isEmployee(creator);
      exists.should.be.equal(false);

      const totalPay = await payroll._totalPay();
      totalPay.should.be.bignumber.equal(0);
    })
    it('Cannot add the same employee twice', async () => {
      await assertRevert(payroll.addEmployee(creator, [token2.address, token3.address], yearlySalary));
    })
    it('Cannot remove the same employee twice', async () => {
      let emp0 = await payroll.getEmployee(0);

      await payroll.removeEmployee(0);
      await assertRevert(payroll.removeEmployee(0));
    })
    it('Adds an old employee', async () => {
      await payroll.removeEmployee(0);
      await payroll.addEmployee(creator, [token2.address, token3.address], yearlySalary);

      const emp = await payroll.getEmployee(1);

      emp[0].should.be.equal(creator);
    })
    it('Adds funds to the contract', async () => {
      await payroll.addFunds({ value: seedFund });

      const balance = await payroll._balance();

      balance.should.be.bignumber.equal(seedFund);
    })
    it('Runs off with the money (scapeHatch)', async () => {
      await payroll.addFunds({ value: seedFund });

      let balance = await payroll._balance();

      balance.should.be.bignumber.equal(seedFund);
      const oldBalance = await web3.eth.getBalance(creator);

      await payroll.scapeHatch();

      const newBalance = await web3.eth.getBalance(creator);
      balance = await payroll._balance();

      balance.should.be.bignumber.equal(0);

      oldBalance.should.be.bignumber.below(newBalance);
    })
  })

  describe('Getter Functions', () => {
    it('Gets the employee count', async () => {
      const count = await payroll.getEmployeeCount();

      count.should.be.bignumber.equal(1);
    })
    it('Gets a new employee', async () => {
      const emp = await payroll.getEmployee(0);

      emp[0].should.be.equal(creator);
    })
    it('Calculates the burn rate', async () => {
      let burnRate = await payroll.calculatePayrollBurnrate();
      burnRate = burnRate.toNumber();
      burnRate.should.be.equal(yearlySalary / 12);

      // Add a second user
      await payroll.addEmployee(user, [user, anotherUser], yearlySalary);
      burnRate = await payroll.calculatePayrollBurnrate();
      burnRate = burnRate.toNumber();
      burnRate.should.be.equal(2*yearlySalary / 12);
      // Add a third user but remove them
      await payroll.addEmployee(anotherUser, [user, anotherUser], yearlySalary);
      await payroll.removeEmployee(2);

      burnRate = await payroll.calculatePayrollBurnrate();
      burnRate = burnRate.toNumber();
      burnRate.should.be.equal(2 * yearlySalary / 12);
    })
    it('Calculates the runway', async () => {
      let runway = await payroll.calculatePayrollRunway();

      runway.should.be.bignumber.equal(0);

      await payroll.addFunds({ value: yearlySalary });

      runway = await payroll.calculatePayrollRunway();

      runway.should.be.bignumber.equal(365 * ethExchange);
    })
  })

  describe('Employee Functions', () => {
    beforeEach(async () => {
      await payroll.addFunds({ value: yearlySalary });
    })

    it('Calls the payday function after 30 days', async () => {
      await increaseTimeTo(Date.now() + duration.seconds(oneContractMonth));
      let emp = await payroll.getEmployee(0);

      const lastPayday = emp[2].toNumber()

      const oldBalance = await web3.eth.getBalance(creator);

      await payroll.payday(0);

      const newBalance = await web3.eth.getBalance(creator);

      // This test may fail if exchange rates or pay is very low. E.g.
      // User spent more on TX fee than getting paid. Not a problem
      // with this coin so much.
      newBalance.should.be.bignumber.gt(oldBalance);

      emp = await payroll.getEmployee(0);

      emp[2].should.be.bignumber.equal(lastPayday + oneContractMonth);
      await assertRevert(payroll.payday(0));
    })
    it('Cannot call payday before payday', async () => {
      await assertRevert(payroll.payday(0));
    })
    it('Time Travels three months and calls payday three times', async () => {
      // +4 because we went ahead a month above.
      await increaseTimeTo(Date.now() + duration.seconds(oneContractMonth * 4));
      let emp = await payroll.getEmployee(0);

      await payroll.payday(0);
      await payroll.payday(0);
      await payroll.payday(0);
      emp = await payroll.getEmployee(0);

      await assertRevert(payroll.payday(0));
    })
  })

  describe('Oracle Functions', () => {
    it('Sets Exchange Rates', async () => {
      const tkn1 = await payroll.getExchangeRate(token1.address);
      const tkn2 = await payroll.getExchangeRate(token2.address);
      const tkn3 = await payroll.getExchangeRate(token3.address);

      tkn1.should.be.bignumber.equal(tknExchange1);
      tkn2.should.be.bignumber.equal(tknExchange2);
      tkn3.should.be.bignumber.equal(tknExchange3);
    })
  })

  /*
   * Deserves it's own file. I got ahead of myself
   */

  describe('Token Payroll Functions', () => {
    beforeEach(async () => {
      await tokenPayroll.addEmployee(mallory, [token1.address, token2.address], yearlySalary);

      await tokenPayroll.setExchangeRate(payroll.address, ethExchange, fromOracle);
      await tokenPayroll.setExchangeRate(token1.address, tknExchange1, fromOracle);
      await tokenPayroll.setExchangeRate(token2.address, tknExchange2, fromOracle);
      await tokenPayroll.setExchangeRate(token3.address, tknExchange3, fromOracle);

      await token1.transferToContract(tokenPayroll.address, yearlySalary * 10, '');
      await token2.transferToContract(tokenPayroll.address, yearlySalary * 10, '');
    })
    it('Increases the count of employees accepting a token', async () => {
      const tokenCount = await tokenPayroll.allowedTokenCount(token1.address);
      tokenCount.should.be.bignumber.equal(1);
    })
    it('Decreases the count of employees accepting a token after removing an employee', async () => {
      // Sorry Mallory
      await tokenPayroll.removeEmployee(0);
      const tokenCount = await tokenPayroll.allowedTokenCount(token1.address);
      tokenCount.should.be.bignumber.equal(0);
    })
    it('Receives tokens employees want', async () => {
      const contractBalance = await token1.balanceOf(tokenPayroll.address);
      const payrollBalance = await tokenPayroll.tokenBalance(token1.address);

      contractBalance.should.be.bignumber.equal(payrollBalance);
    })
    it('Rejects tokens from contracts no one wants', async () => {
      await assertRevert(token3.transferToContract(tokenPayroll.address, 10000, ''));
    })
    it('Pays out tokens on payday', async () => {
      await increaseTimeTo(Date.now() + duration.seconds(oneContractMonth * 5));

      const balanceBefore = await token2.balanceOf(mallory);
      await tokenPayroll.tokenPayday(0, token2.address, {from: mallory});
      const balanceAfter = await token2.balanceOf(mallory);

      const monthlySalary = Math.round(yearlySalary / tknExchange2 / 12);
      const currentBalance = balanceAfter.toNumber();

      currentBalance.should.be.equal(monthlySalary);
    })
    it('Calculates runway for the given token', async () => {
      const t1 = await tokenPayroll.calculateTokenPayrollRunway(token1.address);
      // 365 * 10 - see beforeEach yearlySalary * 10
      t1.should.be.bignumber.equal(365 * 10);
    })
    it('Runs off with the tokens and money (scape hatch)', async () => {
      const befBal1 = await token1.balanceOf(creator);
      const befBal2 = await token2.balanceOf(creator);

      await tokenPayroll.tokenScapeHatch();

      const aftBal1 = await token1.balanceOf(creator);
      const aftBal2 = await token2.balanceOf(creator);

      aftBal1.should.be.bignumber.gt(befBal1);
      aftBal2.should.be.bignumber.gt(befBal2);
    })
    it('Withdraws tokens one at a time', async () => {
      const befBal1 = await token1.balanceOf(creator);
      const befBal2 = await token2.balanceOf(creator);

      await tokenPayroll.tokenScapeHatchSingle(token1.address);
      await tokenPayroll.tokenScapeHatchSingle(token2.address);

      const aftBal1 = await token1.balanceOf(creator);
      const aftBal2 = await token2.balanceOf(creator);

      aftBal1.should.be.bignumber.gt(befBal1);
      aftBal2.should.be.bignumber.gt(befBal2);
    })
  })
})

