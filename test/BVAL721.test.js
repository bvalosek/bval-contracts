const truffleAssert = require('truffle-assertions');
const timeMachine = require('ganache-time-traveler');

const { toBN } = web3.utils;

const BVAL721 = artifacts.require('BVAL721');
const BVAL20 = artifacts.require('BVAL20');

const BASE_URI = 'https://tokens.test.com/';

const createTimestamp = (date) => Math.round(new Date(date).getTime() / 1000);

const factory = async (startDate = '2021-03-07') => {
  await timeMachine.advanceBlockAndSetTime(createTimestamp(startDate));
  const token = await BVAL20.new();
  const collection = await BVAL721.new(BASE_URI, token.address);
  return { token, collection };
}

const BVAL = (amount) => toBN(`${amount}`).mul(toBN('1000000000000000000'));
const LAVB = (amount) => toBN(`${amount}`).div(toBN('1000000000000000000')).toNumber();

// max gas for deployment
const MAX_DEPLOYMENT_GAS = 4000000;

// max amount of gas we want to allow for basic on-chain mutations
const MAX_MUTATION_GAS = 150000;

// max amount of gas we want to allow for basic on-chain logs
const MAX_ANNOUNCE_GAS = 60000;

// decimal tokens , generated with token ID encoder util
const TOKENS = [
  // 1 - 1 minted 2021-03-07
  '542422083536764891605055617762608442122700715211722983994819756335223078913',
  // 2 - 10 minted 2021-03-07
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

contract.only('BVAL721', (accounts) => {
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
  describe('accumulation calculation', () => {
    it('should accumulate based on date', async () => {
      const { collection } = await factory();
      await collection.setBaseDailyRate(BVAL(1));
      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-07'));
      assert.equal(LAVB(await collection.accumulated(tokenId)), 0); // none to start
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2022-03-07'));
      assert.equal(LAVB(await collection.accumulated(tokenId)), 3650); // 10 per day for a year
    });
    it('should accumulate 0 if mint date in the future', async () => {
      const { collection } = await factory();
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2020-03-07')); // before mint date

      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);
      assert.equal(await collection.accumulated(tokenId), 0);
    });
    it('should revert on a non-existent token', async () => {
      const { collection } = await factory();
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-07'));
      const [tokenId] = TOKENS;
      const task = collection.accumulated(tokenId);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'invalid token');
    });
  });
  describe('claiming BVAL', () => {
    it('should claim accumulated bval', async () => {
      const [a1, a2] = accounts;
      const { collection, token } = await factory();
      await token.mintTo(collection.address, BVAL(1000));
      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);
      await collection.transferFrom(a1, a2, tokenId);

      // 1 day later
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-08'));
      await collection.claim([tokenId], { from: a2 });
      assert.equal(LAVB(await token.balanceOf(collection.address)),990);
      assert.equal(LAVB(await token.balanceOf(a1)), 0);
      assert.equal(LAVB(await token.balanceOf(a2)), 10);

      // 2 days later
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-09'));
      await collection.claim([tokenId], { from: a2 });
      assert.equal(LAVB(await token.balanceOf(collection.address)),980);
      assert.equal(LAVB(await token.balanceOf(a1)), 0);
      assert.equal(LAVB(await token.balanceOf(a2)), 20);
    });
    it('should revert if nothing to claim', async () => {
      const { collection } = await factory();
      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2020-03-07'));
      const task = collection.claim([tokenId]);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'nothing to claim');
    });
    it('should revert if non-token holder tries to claim', async () => {
      const [a1, a2] = accounts;
      const { collection, token } = await factory();
      await token.mintTo(collection.address, BVAL(1000));
      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);
      await collection.transferFrom(a1, a2, tokenId);

      // 1 day later
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-08'));
      const task = collection.claim([tokenId]);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'only token holder can claim');
    });
    it('should revert if not enough BVAL held by contract', async () => {
      const { collection } = await factory();
      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);

      // 1 day later
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-08'));
      const task = collection.claim([tokenId]);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'transfer amount exceeds balance');
    });
  })
  describe('token locking', () => {
    it('should allow token holder to lock', async () => {
      const { collection} = await factory();
      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-08'));
      await collection.lockTokens([tokenId]);
      const eat = await collection.tokenLockExpiresAt(tokenId);
      assert.equal(eat.toNumber(), 1615248000);
    });
    it('should revert if non-holder attempts to lock', async () => {
      const [,a2] = accounts;
      const { collection} = await factory();
      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);
      const task = collection.lockTokens([tokenId], { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'not token owner');
    });
    it('should revert on claim if token locked', async () => {
      const { collection} = await factory();
      const [tokenId] = TOKENS;
      await simpleMint(collection, tokenId);
      await collection.lockTokens([tokenId]);
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-08'));
      const task = collection.claim([tokenId]);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'token is locked');
    });
  });
});
