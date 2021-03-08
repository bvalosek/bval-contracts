const truffleAssert = require('truffle-assertions');
const timeMachine = require('ganache-time-traveler');

const BVAL20 = artifacts.require('BVAL20');

const factory = async (startDate = '2021-02-07') => {
  await timeMachine.advanceBlockAndSetTime(createTimestamp(startDate));
  return BVAL20.new();
};

const createTimestamp = (date) => Math.round(new Date(date).getTime() / 1000);

// max gas for deployment
const MAX_DEPLOYMENT_GAS = 1800000;

let snapshotId;
beforeEach(async () => {
  const snapshot = await timeMachine.takeSnapshot();
  snapshotId = snapshot['result'];
});

afterEach(async () => {
  await timeMachine.revertToSnapshot(snapshotId);
});

contract('BVAL20', (accounts) => {
  describe('gas constraints', () => {
    it('should deploy with less than target deployment gas', async () => {
      const instance = await factory();
      let { gasUsed } = await web3.eth.getTransactionReceipt(instance.transactionHash);
      assert.isBelow(gasUsed, MAX_DEPLOYMENT_GAS);
      console.log('deployment', gasUsed);
    });
  });
  describe('metadata', () => {
    it('should return name', async () => {
      const instance = await factory();
      const name = await instance.name();
      assert.equal(name, '@bvalosek Token');
    });
    it('should return symbol', async () => {
      const instance = await factory();
      const symbol = await instance.symbol();
      assert.equal(symbol, 'BVAL');
    });
  });
  describe('OPERATOR_ROLE functionality', () => {
    it('should allow an account with OPERATOR_ROLE the ability to move tokens without allowance', async () => {
      const [a1, a2, a3] = accounts;
      const instance = await factory();
      await instance.grantRole(await instance.OPERATOR_ROLE(), a2);
      await instance.mintTo(a1, 1000);
      await instance.transferFrom(a1, a3, 1000, { from: a2 });
      assert.equal(await instance.balanceOf(a3), 1000);
    });
    it('should function as normal for non-OPERATOR_ROLE accounts', async () => {
      const [a1, a2, a3] = accounts;
      const instance = await factory();
      await instance.mintTo(a1, 1000);
      const task = instance.transferFrom(a1, a3, 1000, { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'transfer amount exceeds allowance');
    });
  });
  describe('burn', () => {
    it('should allow burning held tokens', async () => {
      const [a1] = accounts;
      const instance = await factory();
      await instance.mintTo(a1, 1000);
      assert.equal(await instance.balanceOf(a1), 1000);
      await instance.burn(1000);
      assert.equal(await instance.balanceOf(a1), 0);
      const task = instance.burn(1000);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'burn amount exceeds balance');
    });
    it('should not allow burning more than balance', async () => {
      const instance = await factory();
      const task = instance.burn(1000);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'burn amount exceeds balance');
    });
  });
  describe('role renouncement', () => {
    // mostly proving to myself this works like i think it does, this is
    // really testing the underlying AccessControl functionality from open zep
    it('should allow eventual minting lockout', async () => {
      const [a1, a2] = accounts;
      const instance = await factory();
      await instance.revokeRole(await instance.MINTER_ROLE(), a1);
      await instance.revokeRole(await instance.MINTER_ADMIN_ROLE(), a1);

      // can no longer mint
      const task1 = instance.mintTo(a1, 1000);
      await truffleAssert.fails(task1, truffleAssert.ErrorType.REVERT, 'requires MINTER_ROLE');

      // can no longer assign mint role
      const task2 = instance.grantRole(await instance.MINTER_ROLE(), a1);
      await truffleAssert.fails(task2, truffleAssert.ErrorType.REVERT, 'sender must be an admin to grant');

      assert.equal(await instance.getRoleMemberCount(await instance.MINTER_ROLE()), 0);
      assert.equal(await instance.getRoleMemberCount(await instance.MINTER_ADMIN_ROLE()), 0);

      // can still grant operator role
      await instance.grantRole(await instance.OPERATOR_ROLE(), a2);
    });
  });
});
