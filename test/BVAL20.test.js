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
  describe('deadmans switch', () => {
    it('should not allow minting after deadmans switch is tripped', async () => {
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-02-28'));
      const instance = await factory();
      await instance.mintTo(instance.address, 10000); // doesnt revert
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2023-02-28'));
      const task = instance.mintTo(instance.address, 10000); // doesnt revert
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'has been tripped');
    });
    it('should not allow resetting timer after switch has tripped', async () => {
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-02-28'));
      const instance = await factory();
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2023-02-28'));

      const task = instance.pingDeadmanSwitch();
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'has been tripped');
    });
  });
});
