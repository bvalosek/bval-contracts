const truffleAssert = require('truffle-assertions');
const timeMachine = require('ganache-time-traveler');

const BVAL721 = artifacts.require('BVAL721');
const BVAL20 = artifacts.require('BVAL20');

const BASE_URI = 'https://tokens.test.com/';

const createTimestamp = (date) => Math.round(new Date(date).getTime() / 1000);


const factory = async (startDate = '2021-02-07') => {
  await timeMachine.advanceBlockAndSetTime(createTimestamp(startDate));
  const token = await BVAL20.new();
  const collection = await BVAL721.new(BASE_URI, token.address);
  return { token, collection };
}

// max gas for deployment
const MAX_DEPLOYMENT_GAS = 4000000;

// max amount of gas we want to allow for basic on-chain mutations
const MAX_MUTATION_GAS = 150000;

// max amount of gas we want to allow for basic on-chain logs
const MAX_ANNOUNCE_GAS = 60000;

// decimal tokens , generated with token ID encoder util
const TOKENS = [
  // 1 - 1
  '542422083536764891605055617762608442122700715211722983994819756335223078913',
  // 2 - 10
  '724407358168885144702775055006144136272562230227056159221917676176268132353',
];

let snapshotId;
beforeEach(async () => {
  const snapshot = await timeMachine.takeSnapshot();
  snapshotId = snapshot['result'];
});

afterEach(async () => {
  await timeMachine.revertToSnapshot(snapshotId);
});

// start a sequence and mint
const simpleMint = async (instance, tokenId = TOKENS[0]) => {
  await instance.startSequence('1', 'name', 'desc', 'data');
  const res = await instance.mint(tokenId, 'name', 'desc', 'data');
  return res;
}

contract('BVAL721', (accounts) => {
  describe('gas constraints', () => {
    it('should deploy with less than target deployment gas', async () => {
      const { collection } = await factory();
      let { gasUsed } = await web3.eth.getTransactionReceipt(collection.transactionHash);
      assert.isBelow(gasUsed, MAX_DEPLOYMENT_GAS);
      console.log('deploy', gasUsed);
    });
  });
  describe('admin functionality', () => {
    it('should allow setting daily base rate', async () => {
      const { collection } = await factory();
      await collection.setBaseDailyRate(12345);
      assert.equal(await collection.baseDailyRate(), 12345);
    });
    it('should not allow non-admin to set rate', async () => {
      const [, a2] = accounts;
      const { collection } = await factory();
      const task = collection.setBaseDailyRate(12345, { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'requires DEFAULT_ADMIN_ROLE');
    });
    it('should allow setting base burn amount', async () => {
      const { collection } = await factory();
      await collection.setBaseBurnAmount(56789);
      assert.equal(await collection.baseBurnAmount(), 56789);
    });
    it('should not allow non-admin to set rate', async () => {
      const [, a2] = accounts;
      const { collection } = await factory();
      const task = collection.setBaseBurnAmount(56789, { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'requires DEFAULT_ADMIN_ROLE');
    });
  });
});
