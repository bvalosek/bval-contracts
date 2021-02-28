const truffleAssert = require('truffle-assertions');

const BVAL721 = artifacts.require('BVAL721');
const MockSequenceEngine = artifacts.require('MockSequenceEngine');
const DESC = 'description';
const IMAGE = 'https://image';
const BASE_URI = 'https://tokens.test.com/';

// if no from, defaults to default address for wallet
const factory = () => BVAL721.new({ description: DESC, data: IMAGE, baseURI: BASE_URI });

// max gas for deployment
const MAX_DEPLOYMENT_GAS = 2800000;

// max amount of gas we want to allow for basic on-chain mutations
const MAX_MUTATION_GAS = 100000;

// max amount of gas we want to allow for basic on-chain logs
const MAX_ANNOUNCE_GAS = 50000;

// decimal tokens , generated with token ID encoder util
const TOKENS = [
  // 1/1/1
  '530054119433515298874989250222875555156328978334254252466069431952628318209',
  // 1/2/1
  '535354660627850451863739142725104310703811430024881109340434250556506243073',
  // 2/1/1
  '625463860931548052672487315262993155011013108765537676204636166826724753409',
];

// start a sequence and mint
const simpleMint = async (instance, tokenId = TOKENS[0]) => {
  await instance.startSequence('1', 'name', 'desc', 'data');
  const res = await instance.mint(tokenId, 'name', 'desc', 'data');
  return res;
}


contract('BVAL721', (accounts) => {
  describe('gas constraints', () => {
    it('should deploy with less than target deployment gas', async () => {
      const instance = await factory();
      let { gasUsed } = await web3.eth.getTransactionReceipt(instance.transactionHash);
      assert.isBelow(gasUsed, MAX_DEPLOYMENT_GAS);
    });
    it('mint should cost less than target mutation gas', async () => {
      const instance = await factory();
      const res = await simpleMint(instance);
      assert.isBelow(res.receipt.gasUsed, MAX_MUTATION_GAS);
    });
    it('mint with longer strings should cost less than target mutation gas', async () => {
      const instance = await factory();
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      const res = await instance.mint(
        tokenId,
        'Example Token Name',
        'This is an example of a token description that is a bit longer. Multiple sentences for more detail.',
        'QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU'
      );
      assert.isBelow(res.receipt.gasUsed, MAX_MUTATION_GAS);
    });
    it('start sequence should cost less than target announce gas', async () => {
      const instance = await factory();
      const res = await instance.startSequence('1', 'name', 'desc', 'image');
      assert.isBelow(res.receipt.gasUsed, MAX_ANNOUNCE_GAS);
    });
    it('start seqeunce with longer strings should cost less than target announce gas', async () => {
      const instance = await factory();
      const res = await instance.startSequence(
        '1',
        'Example Sequence Name',
        'This is a bit more realistic example of sequence metadata. At least two sentences for plenty of detail',
        'QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU'
      );
      assert.isBelow(res.receipt.gasUsed, MAX_ANNOUNCE_GAS);
    });
    it('complete seqeunce should cost less than target announce gas', async () => {
      const instance = await factory();
      await instance.startSequence('1', 'name', 'desc', 'image');
      const res = await instance.completeSequence('1');
      assert.isBelow(res.receipt.gasUsed, MAX_ANNOUNCE_GAS);
    });
  });
  describe('erc165 checks', () => {
    it('should implement ERC-165', async () => {
      const instance = await factory();
      assert.isTrue(await instance.supportsInterface('0x01ffc9a7'));
    });
    it('should implement ERC-721', async () => {
      const instance = await factory();
      assert.isTrue(await instance.supportsInterface('0x80ac58cd'));
    });
    it('should implement ERC-721Metadata', async () => {
      const instance = await factory();
      assert.isTrue(await instance.supportsInterface('0x5b5e139f'));
    });
    it('should implement Rarible HasSecondarySaleFees', async () => {
      const instance = await factory();
      assert.isTrue(await instance.supportsInterface('0xb7799584'));
    });
    it('should implement OpenSea Collection Metadata', async () => {
      const instance = await factory();
      assert.isTrue(await instance.supportsInterface('0xe8a3d485'));
    });
    it('should implement ITokenState', async () => {
      const instance = await factory();
      assert.isTrue(await instance.supportsInterface('0xb3edd64b'));
    });
    it('should implement IERC2981', async () => {
      const instance = await factory();
      assert.isTrue(await instance.supportsInterface('0xcef6d368'));
    });
  });
  describe('Ownable access semantics', () => {
    it('should expose owner defaulting to sender', async () => {
      const [a1] = accounts;
      const instance = await factory();
      const owner = await instance.owner();
      assert.equal(owner, a1);
    });
    it('should allow transfer to another owner', async () => {
      const [, a2] = accounts;
      const instance = await factory();
      await instance.transferOwnership(a2);
      const owner = await instance.owner();
      assert.equal(owner, a2);
    });
    it('should not allow non-owner to transfer', async () => {
      const [, a2] = accounts;
      const instance = await factory();
      const task = instance.transferOwnership(a2, { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'not the owner');
    });
  });
  describe('ERC721 Metadata', () => {
    it('should have a name', async () => {
      const instance = await factory();
      const name = await instance.name();
      assert.isString(name);
      assert.isAbove(name.length, 0);
    });
    it('should have a symbol', async () => {
      const instance = await factory();
      const symbol = await instance.symbol();
      assert.isString(symbol);
      assert.isAbove(symbol.length, 0);
    });
    it('should have a tokenURI', async () => {
      const instance = await factory();
      const tokenId = TOKENS[0];
      await simpleMint(instance, tokenId);
      const uri = await instance.tokenURI(tokenId);
      assert.typeOf(uri, 'string');
      assert.include(uri, tokenId);
      assert.include(uri, BASE_URI);
    });
    it('should have a contractURI', async () => {
      const instance = await factory();
      const uri = await instance.contractURI();
      assert.isString(uri);
      assert.include(uri, BASE_URI);
    });
  });
  describe('base URI override', () => {
    it('should allow owner to override', async () => {
      const instance = await factory();
      const override = 'https://override';
      await instance.setBaseURI(override);
      const tokenId = TOKENS[0];
      await simpleMint(instance, tokenId);
      const uri = await instance.tokenURI(tokenId);
      assert.isString(uri);
      assert.include(uri, override);
    });
    it('should revert if non-owner tries to override', async () => {
      const [, a2] = accounts;
      const instance = await factory();
      const override = 'https://override';
      const task = instance.setBaseURI(override, { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'not the owner');
    });
  });
  describe('minting', () => {
    it('should allow owner to mint', async () => {
      const instance = await factory();
      await simpleMint(instance);
    });
    it('should revert if non-owner attempts to mint', async () => {
      const [, a2] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      const task = instance.mint(tokenId, 'name', 'desc', 'data', { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'not the owner');
    });
    it('should revert if minting before starting first sequence', async () => {
      const instance = await factory();
      const task = instance.mint(TOKENS[0], 'name', 'description', 'image');
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'invalid sequence number');
    });
    it('should revert if minted with wrong sequence number', async () => {
      const instance = await factory();
      await instance.startSequence('1', 'name', 'desc', 'image');
      const task = instance.mint(TOKENS[1], 'name', 'description', 'image');
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'invalid sequence number');
    });
    it('should revert if minted with wrong collection version', async () => {
      const instance = await factory();
      await instance.startSequence('1', 'name', 'desc', 'image');
      const task = instance.mint(TOKENS[2], 'name', 'description', 'image');
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'invalid collection version');
    });
    it('should emit a metadata event on minting', async () => {
      const instance = await factory();
      const name = 'name';
      const description = 'desc';
      const data = 'image';
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      const res = await instance.mint(tokenId, name, description, data);
      truffleAssert.eventEmitted(
        res,
        'TokenMetadata',
        (event) =>
          event.name === name &&
          event.description === description &&
          event.data === data &&
          event.tokenId.toString() === tokenId.toString()
      );
    });
    it('should emit a SecondarySaleFees event on minting', async () => {
      const [a1] = accounts;
      const instance = await factory();
      const name = 'name';
      const description = 'desc';
      const data = 'image';
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      const res = await instance.mint(tokenId, name, description, data);
      truffleAssert.eventEmitted(res, 'SecondarySaleFees', (event) => {
        return (
          event.tokenId.toString() === tokenId &&
          event.recipients[0].toString() === a1.toString() &&
          event.bps[0].toNumber() === 1000
        );
      });
    });
    it('should allow overriding token uri', async () => {
      const instance = await factory();
      const tokenId = TOKENS[0];
      const override = 'https://override';
      await instance.startSequence('1', 'name', 'desc', 'image');
      await instance.mint(tokenId, 'name', 'description', 'image');
      await instance.setTokenURI(tokenId, override);
      const uri = await instance.tokenURI(tokenId);
      assert.equal(uri, override);
    });
    it('should not allow non-owner to override', async () => {
      const [, a2] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      const override = 'https://override';
      await instance.startSequence('1', 'name', 'desc', 'image');
      await instance.mint(tokenId, 'name', 'description', 'image');
      const task = instance.setTokenURI(tokenId, override, { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'not the owner');
    });
  });
  describe('burning', () => {
    it('should allow owner to burn', async () => {
      const [a1] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      assert.equal(await instance.balanceOf(a1), 0);
      await simpleMint(instance, tokenId);
      assert.equal(await instance.balanceOf(a1), 1);
      await instance.burn(tokenId);
      assert.equal(await instance.balanceOf(a1), 0);
    });
    it('should allow (non owner) token holder to burn', async () => {
      const [a1, a2] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      await simpleMint(instance, tokenId);
      await instance.safeTransferFrom(a1, a2, tokenId);
      assert.equal(await instance.balanceOf(a1), 0);
      assert.equal(await instance.balanceOf(a2), 1);
      await instance.burn(tokenId, { from: a2 });
      assert.equal(await instance.balanceOf(a1), 0);
      assert.equal(await instance.balanceOf(a2), 0);
    });
    it('should revert if non-owner attempts to burn', async () => {
      const [a1, a2] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      await simpleMint(instance, tokenId);
      assert.equal(await instance.balanceOf(a1), 1);
      const task = instance.burn(tokenId, { from: a2 });
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'not token owner');
      assert.equal(await instance.balanceOf(a1), 1);
    });
    it('should revert if owner attempts to burn non-held token', async () => {
      const [a1, a2] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      await simpleMint(instance, tokenId);
      await instance.safeTransferFrom(a1, a2, tokenId);
      const task = instance.burn(tokenId);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'not token owner');
      assert.equal(await instance.balanceOf(a1), 0);
      assert.equal(await instance.balanceOf(a2), 1);
    });
  });
  describe('rarible royalties', () => {
    it('should return fee bps value', async () => {
      const instance = await factory();
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      await instance.mint(tokenId, 'name', 'description', 'image');
      const fee = await instance.getFeeBps(tokenId);
      assert.isNumber(fee[0].toNumber());
      assert.lengthOf(fee, 1);
    });
    it('should return owner as fee recipient', async () => {
      const [a1] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      await instance.mint(tokenId, 'name', 'description', 'image');
      const rec = await instance.getFeeRecipients(tokenId);
      assert.equal(rec[0], a1);
      assert.lengthOf(rec, 1);
    });
  });
  describe('IERC2981 royalities', () => {
    it('should return royality information', async () => {
      const [a1] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      await instance.mint(tokenId, 'name', 'description', 'image');
      const rec = await instance.royaltyInfo(tokenId);
      assert.equal(rec[0].toString(), a1);
      assert.equal(rec[1].toNumber(), 100000);
    });
  });
  describe('token state', () => {
    it('should have a default token state of zero', async () => {
      const instance = await factory();
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      await instance.mint(tokenId, 'name', 'description', 'image');
      const state = await instance.getTokenState(tokenId);
      assert.equal(state.toNumber(), 0);
    });
    it('should reflect set state', async () => {
      const instance = await factory();
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      await instance.mint(tokenId, 'name', 'description', 'image');

      const s1 = await instance.getTokenState(tokenId);
      assert.equal(s1.toNumber(), 0);

      await instance.setTokenState(tokenId, 123, 0);
      const s2 = await instance.getTokenState(tokenId);
      assert.equal(s2.toNumber(), 123);
    });
    it('should not allow non-holder to set state', async () => {
      const [a1, a2] = accounts;
      const instance = await factory();
      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image');
      await instance.mint(tokenId, 'name', 'description', 'image');
      await instance.safeTransferFrom(a1, a2, tokenId);

      const task = instance.setTokenState(tokenId, 123, 0);
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'not token owner');

      await instance.setTokenState(tokenId, 123, 0, { from: a2 });
      const state = await instance.getTokenState(tokenId);
      assert.equal(state.toNumber(), 123);
    });
    it('should revert if bribing state change w/o coin contract set', async () => {
      const instance = await factory();
      const tokenId = TOKENS[0];
      await simpleMint(instance, tokenId);

      const task = instance.setTokenState(tokenId, 123, '5000000000');
      await truffleAssert.fails(task, truffleAssert.ErrorType.REVERT, 'coin address not yet set');
    });
  });
  describe('sequence engines', () => {
    it('should call the sequence engine on state change', async () => {
      const instance = await factory();
      const engine = await MockSequenceEngine.new();

      const tokenId = TOKENS[0];
      await instance.startSequence('1', 'name', 'desc', 'image', engine.address);
      await instance.mint(tokenId, 'name', 'description', 'image');

      assert.equal((await engine.count()).toNumber(), 0);

      await instance.setTokenState(tokenId, 123123123, 0);
      assert.equal((await engine.count()).toNumber(), 1);
      assert.equal((await instance.getTokenState(tokenId)).toNumber(), 1);

      await instance.setTokenState(tokenId, 123123123, 0);
      assert.equal((await engine.count()).toNumber(), 2);
      assert.equal((await instance.getTokenState(tokenId)).toNumber(), 2);
    });
  });
});
