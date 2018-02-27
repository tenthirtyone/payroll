const BigNumber = web3.BigNumber

const ANTPayroll = artifacts.require('ANTPayroll')

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

const expect = require('chai').expect

contract('Payroll Test', accounts => {
  const [creator, user, anotherUser, oracle, mallory] = accounts
  const addresses = [
    '0x281055afc982d96fab65b3a49cac8b878184cb16',
    '0x6f46cf5569aefa1acc1009290c8e043747172d89',
    '0x90e63c3d53e0ea496845b7a03ec7548b70014a91',
    '0xab7c74abc0c4d48d1bdad5dcb26153fc8780f83e'
  ]

  const [Tkn1, Tkn2, Tkn3, Tkn4] = addresses;

  let payroll = null

  const oneTkn1 = 1 * 10e10;
  const oneTkn2 = 92 * 10e10;
  const oneTkn3 = 531 * 10e10;
  const oneTkn4 = 123 * 10e10;

  const oneEth = 10 * 10e18;
  const yearlySalary = 400000;

  beforeEach(async () => {
    payroll = await ANTPayroll.new(oracle);
    await payroll.addEmployee(creator, [user, anotherUser], yearlySalary);
  })

  describe('Owner Functions', () => {
    it('Adds a new employee', async () => {
      const emp = await payroll._employees(0);

      emp[0].should.be.equal(creator);
    })
    it('Sets an employees salary', async () => {
      await payroll.setEmployeeSalary(0, 5000);

      const emp = await payroll.getEmployee(0);

      emp[1].should.be.bignumber.equal(5000);
    })
    it('Removes an employee (set inactive)', async () => {
      await payroll.removeEmployee(0);

      const emp = await payroll.getEmployee(0);

      emp[2].should.be.equal(false);
    })
    it('Adds funds to the contract', async () => {
      await payroll.addFunds({ value: oneEth });

      const balance = await payroll._balance();

      balance.should.be.bignumber.equal(oneEth);
    })
    it('Runs off with the money (scapeHatch)', async () => {
      await payroll.addFunds({ value: oneEth });

      let balance = await payroll._balance();

      balance.should.be.bignumber.equal(oneEth);
      const oldBalance = await web3.eth.getBalance(creator);

      await payroll.scapeHatch(creator);

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
      await payroll.addEmployee(user, [user, anotherUser], yearlySalary);
      await payroll.addEmployee(anotherUser, [user, anotherUser], yearlySalary);

      const burnRate = await payroll.calculatePayrollBurnrate();

      burnRate.should.be.bignumber.equal(yearlySalary * 3 / 12);
    })
    it('Calculates the runway', async () => {

    })
  })

  describe('Oracle Functions', () => {
    beforeEach(async () => {
      payroll.setExchangeRate(Tkn1, oneTnk1);
      payroll.setExchangeRate(Tkn2, oneTnk2);
      payroll.setExchangeRate(Tkn3, oneTnk3);
      payroll.setExchangeRate(Tkn4, oneTnk4);
    })

    it('Sets Exchange Rates', async () => {

    })
  })
})

