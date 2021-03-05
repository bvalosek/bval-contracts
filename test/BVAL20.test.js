const truffleAssert = require('truffle-assertions');
const timeMachine = require('ganache-time-traveler');

const BVAL20 = artifacts.require('BVAL20');
const BVAL721 = artifacts.require('BVAL721');

const factory = async (startDate = '2021-02-07') => {
  await timeMachine.advanceBlockAndSetTime(createTimestamp(startDate));
  return BVAL20.new();
};

const factory721 = () => BVAL721.new({ description: 'desc', data: 'data', baseURI: 'uri' });

const TOKENS = [
  // emission rate = 10, cost = 0
  '0x01510000000a000000000000000960096001488848fe00010001000100010001',
  // emission rate = 10, cost = 10
  '0x0123000a000a000000000000000960096001488848fe00010001000100010001',
  // emission rate = 10, cost = 0, mint date = 2025-02-28
  '0x01ba0000000a00000000000000096009600148884eb300010001000100010001',
];

const mintNFT = async (instance, tokenId = TOKENS[0]) => {
  await instance.startSequence('1', 'name', 'desc', 'image');
  await instance.mint(tokenId, 'name', 'desc', 'data');
  return tokenId;
};

const createTimestamp = (date) => Math.round(new Date(date).getTime() / 1000);

// max gas for deployment
const MAX_DEPLOYMENT_GAS = 1500000;

// max amount of gas we want to allow for basic on-chain mutations
const MAX_MUTATION_GAS = 100000;

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
    // it('should cost below target gas to claim', async () => {
    //   const instance = await factory();
    //   const instance721 = await factory721();
    //   await instance.setContract(1, instance721.address);
    //   const tokenId = await mintNFT(instance721);
    //   await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-01'));
    //   const res = await instance.claim([tokenId]);
    //   assert.isBelow(res.receipt.gasUsed, MAX_MUTATION_GAS);
    // });
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
  // describe('setContract', () => {
  //   it('should allow setting contracts', async () => {
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance.setContract(1, instance721.address);
  //     const address = await instance.getContract(1);
  //     assert.equal(address.toString(), instance721.address.toString());
  //   });
  //   it('should revert if same collection version set twice', async () => {
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance.setContract(1, instance721.address);
  //     const task = instance.setContract(1, instance721.address);
  //     await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'collection version already set');
  //   });
  // });
  // describe('accumulation calculation', () => {
  //   it('should accumulate based on date', async () => {
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     const tokenId = await mintNFT(instance721);
  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-01'));
  //     const accumulated = await instance.accumulated(tokenId);
  //     assert.equal(accumulated.toString(), '310000000000000000000'); // 10 + 300 bonus
  //   });
  //   it('should accumulate bonus right from the start', async () => {
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     const tokenId = await mintNFT(instance721);
  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-02-28'));
  //     const accumulated = await instance.accumulated(tokenId);
  //     assert.equal(accumulated.toString(), '300000000000000000000');
  //   });
  //   it('should accumulate 0 if mint date in the future', async () => {
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     const tokenId = await mintNFT(instance721);
  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-01-01'));
  //     const accumulated = await instance.accumulated(tokenId);
  //     assert.equal(accumulated.toString(), '0');
  //   });
  //   it('should not start with a bonus if minted after bonus date', async () => {
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     const tokenId = await mintNFT(instance721, TOKENS[2]); // tokens mints on 2025-02-28
  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2025-02-28'));
  //     const accumulated = await instance.accumulated(tokenId);
  //     assert.equal(accumulated.toString(), '0');
  //   });
  // });
  // describe('claiming', () => {
  //   it('should claim $BVAL', async () => {
  //     const [a1] = accounts;
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance.setContract(1, instance721.address);
  //     const tokenId = await mintNFT(instance721);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-01'));
  //     await instance.claim([tokenId]);
  //     const balance = await instance.balanceOf(a1);
  //     assert.equal(balance.toString(), '310000000000000000000'); // 10 + 300 bonus

  //     // ensure zero-ed out
  //     const toClaim = await instance.accumulated(tokenId);
  //     assert.equal(toClaim.toString(), '0');
  //   });
  //   it('should revert if nothing to claim', async () => {
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance.setContract(1, instance721.address);
  //     const tokenId = await mintNFT(instance721);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2020-05-01'));
  //     const task = instance.claim([tokenId]);
  //     await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'nothing to claim');
  //   });
  //   it('should revert if provided a non-valid token', async () => {
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance.setContract(1, instance721.address);
  //     const task = instance.claim([0]);
  //     await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'malformed token');
  //   });
  //   it('should revert if non-holder attempts to claim', async () => {
  //     const [, a2] = accounts;
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance.setContract(1, instance721.address);
  //     const tokenId = await mintNFT(instance721);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-05-01'));
  //     const task = instance.claim([tokenId], { from: a2 });
  //     await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'only token holder can claim');
  //   });
  //   it('should not double claim if same tokenId used multiple times', async () => {
  //     const [a1] = accounts;
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance.setContract(1, instance721.address);
  //     const tokenId = await mintNFT(instance721);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-01'));
  //     await instance.claim([tokenId, tokenId, tokenId, tokenId, tokenId]);
  //     const balance = await instance.balanceOf(a1);
  //     assert.equal(balance.toString(), '310000000000000000000'); // 10 + 300
  //   });
  //   it('should only claim newly emitted coins', async () => {
  //     const [a1] = accounts;
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance.setContract(1, instance721.address);
  //     const tokenId = await mintNFT(instance721);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-01'));
  //     await instance.claim([tokenId]);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-02'));
  //     await instance.claim([tokenId]);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-03'));
  //     await instance.claim([tokenId]);

  //     const balance = await instance.balanceOf(a1);
  //     assert.equal(balance.toString(), '330000000000000000000'); // 10 + 10 + 10 + 300 bonus
  //   });
  // });
  describe('deadmans switch', () => {
    // it('should not emit any more coins after deadman switch tripped', async () => {
    //   const [a1] = accounts;
    //   const instance = await factory('2021-02-28'); // start on mint date
    //   const instance721 = await factory721();
    //   await instance.setContract(1, instance721.address);
    //   const tokenId = await mintNFT(instance721);

    //   await timeMachine.advanceBlockAndSetTime(createTimestamp('2025-03-01'));
    //   await instance.claim([tokenId]);
    //   const balance = await instance.balanceOf(a1);
    //   assert.equal(balance.toString(), '3950000000000000000000'); // 365*10 + 30 bonus

    //   // ensure zero-ed out, even after advancing the clock
    //   await timeMachine.advanceBlockAndSetTime(createTimestamp('2030-03-01'));
    //   const toClaim = await instance.accumulated(tokenId);
    //   assert.equal(toClaim.toString(), '0');
    // });
    it('should not allow resetting timer after switch has tripped', async () => {
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-02-28'));
      const instance = await factory();
      await timeMachine.advanceBlockAndSetTime(createTimestamp('2023-02-28'));

      const task = instance.pingDeadmanSwitch();
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'has been tripped');
    });
  });
  // describe('burning on state change', () => {
  //   it('should burn coins on state change', async () => {
  //     const [a1] = accounts;
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance721.setCoinContract(instance.address);
  //     const tokenId = await mintNFT(instance721, TOKENS[1]);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-01'));
  //     await instance.claim([tokenId]);

  //     await instance721.setTokenState(tokenId, '123456', 0);
  //     const balance = await instance.balanceOf(a1);
  //     assert.equal(balance.toString(), '300000000000000000000'); // 10 + 300 - 10
  //   });
  //   it('should allow additional bribe during state change', async () => {
  //     const [a1] = accounts;
  //     const instance = await factory();
  //     const instance721 = await factory721();
  //     await instance721.setCoinContract(instance.address);
  //     const tokenId = await mintNFT(instance721, TOKENS[0]);

  //     await timeMachine.advanceBlockAndSetTime(createTimestamp('2021-03-01'));
  //     await instance.claim([tokenId]);

  //     await instance721.setTokenState(tokenId, '123456', '200000000000000000000');
  //     const balance = await instance.balanceOf(a1);
  //     assert.equal(balance.toString(), '110000000000000000000'); // 10 + 300 - 200
  //   });
  // });
});
