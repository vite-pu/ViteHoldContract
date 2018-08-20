
const _ = require('lodash');
const assert = require('assert');
const BigNumber = require('bignumber.js');
const { promisify } = require('es6-promisify');

const ViteIncentivePlan = artifacts.require("./ViteIncentivePlan.sol");
const ViteToken    = artifacts.require("./ViteToken.sol");

contract('ViteIncentivePlan full test', async (accounts) => {
  const owner = accounts[0];
  const sender = accounts[1];

  let viteToken;
  let vit;
  let tokenAddr;
  let contractAddr;

  const getEthBalanceAsync = async (addr) => {
    const balanceStr = await web3.eth.getBalance(addr);
    const balance = new BigNumber(balanceStr);
    return balance;
  };

  const getTokenBalanceAsync = async (addr) => {
    const tokenBalanceStr = await viteToken.balanceOf(addr);
    const balance = new BigNumber(tokenBalanceStr);
    return balance;
  };

  const advanceBlockTimestamp = async (days) => {
    const seconds = 3600 * 24 * days;
    await web3.currentProvider.send({ jsonrpc: "2.0", method: "evm_increaseTime", params: [seconds], id: 0 })
    await web3.currentProvider.send({ jsonrpc: "2.0", method: "evm_mine", params: [], id: 0 });
  };

  // const sendTransaction = web3.eth.sendTransaction;
  // const getTransactionReceipt = web3.eth.getTransactionReceipt;

  before(async () => {
    viteToken = await ViteToken.deployed();
    vit = await ViteIncentivePlan.deployed();
    tokenAddr = viteToken.address;
    contractAddr = vit.address;
    console.log('tokenAddr', tokenAddr);

    await viteToken.transfer(sender, web3.toWei(200000), {from: owner});
    // await web3.eth.sendTransaction({from: owner, to: sender, value: 0, gas: 100000});

    const _tokenAddrInViteIncenticePlan =  await vit.viteTokenAddress.call();
    console.log('_tokenAddrInViteIncenticePlan',_tokenAddrInViteIncenticePlan);
    const _ownerInViteIncenticePlan = await vit.owner.call();
    console.log('_ownerInViteIncenticePlan',_ownerInViteIncenticePlan);
  });

  describe('ViteIncentivePlan: ', () => {

    it('user should not be able to start program.', async () => {
      try {
        await vit.start({from: sender, gas: 500000});
        throw new Error('start by user, not owner');
      } catch (err) {
        assert(true, 'start by user should have thrown');
      }
    });

    it('owner should be able to start program.', async () => {
      const depositStartTime = await vit.depositStartTime.call();
      assert.equal(depositStartTime.toNumber(), 0, 'depositStartTime should be 0 before start.');

      const closed = await vit.closed.call();
      assert.equal(closed, false, 'closed should be false before start program.');

      await vit.start({from: owner, gas: 500000});
      const depositStartTimeAfter = await vit.depositStartTime.call();
      assert(depositStartTimeAfter.toNumber() > 0, 'depositStartTime should greater than 0 after start.');
    });

    // Succeed
    // it('should be able to deposite eth by owner after started program.', async () => {
    //   const ethPending = await vit.ethPending.call();
    //   console.log('ethPending:', ethPending.toNumber());

    //   const depositStartTime = await vit.depositStartTime.call();
    //   assert(depositStartTime.toNumber() > 0, 'depositStartTime should greater than 0 after start.');

    //   await vit.depositEth({from: owner, value: web3.toWei(2), gas: 500000});

    // });

    // Succeed
    // it('get vite amount about address.', async () => {
    //   const amount = await vit.getViteAmount(sender);
    //   console.log(amount.toNumber());
    // });

    // deposit Vite
    it('should be able to deposite vite token approved during deposite window.',
      async () => {
        const closed = await vit.closed.call();
        console.log("closed:",closed);
        const depositStartTime = await vit.depositStartTime.call();
        console.log('depositStartTime',depositStartTime.toNumber());
        const depositEndTime = await vit.depositEndTime.call();
        console.log('depositEndTime',depositEndTime.toNumber());

        let viteAmount = web3.toWei(150000);
        const tokenBalanceBefore = await getTokenBalanceAsync(contractAddr);
        console.log('tokenBalanceBefore:', tokenBalanceBefore.toNumber());

        await viteToken.approve(contractAddr, viteAmount, {from: sender});

        const viteReceivedBefore = await vit.viteReceived.call();
        console.log('viteReceivedBefore:',viteReceivedBefore.toNumber());

        const senderBalance = await getTokenBalanceAsync(sender);
        console.log('senderBalance:', senderBalance.toNumber());
        
        await vit.depositVite({from: sender, gas: 5000000});

        const senderBalanceAfter = await getTokenBalanceAsync(sender);
        console.log('senderBalanceAfter:', senderBalanceAfter.toNumber());

        const viteReceivedAfter = await vit.viteReceived.call();
        console.log('viteReceivedAfter:', viteReceivedAfter.toNumber());

        const tokenBalanceAfter = await getTokenBalanceAsync(contractAddr);
        console.log('tokenBalanceAfter',tokenBalanceAfter.toNumber());
        // const ethBalanceAfter = await getEthBalanceAsync(sender);

        const tokenOfContractIncreased = 
        tokenBalanceAfter.toNumber() -
        tokenBalanceBefore.toNumber();
        assert.equal(tokenOfContractIncreased, viteAmount, 'token amount error.');
      });

    // withdrawEth during HOLDING_DURATION
    it('should be able to withdraw eth during HOLDING_DURATION.', async () => {
      const tokenBalanceBefore = await getTokenBalanceAsync(contractAddr);
      console.log('tokenBalanceBefore:', tokenBalanceBefore.toNumber());

      const _amountVite = web3.toWei(100000);
      await vit.withdrawEth(_amountVite, {from: sender, gas: 500000});

      const ethPending = await vit.ethPending.call();
      console.log('ethPending:', web3.fromWei(ethPending.toNumber()));
    });

    // depositEth by owner
    it('owner should be able to deposit eth and transfer eth to user.', async () => {
      const ethPending = await vit.ethPending.call();
      console.log('ethPending:', web3.fromWei(ethPending.toNumber()));

      const depositEthAmount = ethPending.toNumber() + 10000000000000;
      console.log('depositEthAmount:', depositEthAmount);

      const ownerTokenBalanceBefore = await getTokenBalanceAsync(owner);
      console.log('ownerTokenBalanceBefore:', ownerTokenBalanceBefore.toNumber());

      const senderEthBefore = await getEthBalanceAsync(sender);
      console.log('senderEthBefore:', web3.fromWei(senderEthBefore.toNumber()));

      await vit.depositEth({from: owner, value: depositEthAmount, gas: 500000});

      const ownerTokenBalanceAfter = await getTokenBalanceAsync(owner);
      console.log('ownerTokenBalanceAfter:', ownerTokenBalanceAfter.toNumber());

      const senderEthAfter = await getEthBalanceAsync(sender);
      console.log('senderEthAfter:', web3.fromWei(senderEthAfter.toNumber()));

      const ethPendingAfter = await vit.ethPending.call();
      console.log('ethPendingAfter:', ethPendingAfter.toNumber());
    });

    // withdrawVite during HOLDING_DURATION
    it('should not be able to withdraw vite during HOLDING_DURATION.', async () => {
      const viteSaved = await vit.getViteAmount(sender);
      console.log('viteSaved:', viteSaved.toNumber());

      await vit.withdrawVite({from: sender, gas: 500000});

      const viteSavedAfter = await vit.getViteAmount(sender);
      console.log('viteSavedAfter:', viteSavedAfter.toNumber());
    });

    // withdrawVite  and  withdrawViteByAmount after HOLDING_DURATION
    it('should be able to withdraw vite after HOLDING_DURATION.', async () => {
      const viteSaved = await vit.getViteAmount(sender);
      console.log('viteSaved:', viteSaved.toNumber());

      await advanceBlockTimestamp(91);

      const senderTokenBefore = await getTokenBalanceAsync(sender);
      console.log('senderTokenBefore:', senderTokenBefore.toNumber());

      // const _amountVite = web3.toWei(20000);
      // await vit.withdrawViteByAmount(_amountVite, {from: sender, gas: 500000});

      await vit.withdrawVite({from: sender, gas: 500000});

      const viteSavedAfter = await vit.getViteAmount(sender);
      console.log('viteSavedAfter:', viteSavedAfter.toNumber());

      const senderTokenAfter = await getTokenBalanceAsync(sender);
      console.log('senderTokenAfter:', senderTokenAfter.toNumber());
    });

    // Succeed
    it('owner should be able to close program.', async () => {
      const depositStartTime = await vit.depositStartTime.call();
      assert(depositStartTime.toNumber() > 0, 'depositStartTime should greater than 0 after start.');

      const closed = await vit.closed.call();
      assert.equal(closed, false, 'closed should be false before start program.');

      await vit.close({from: owner, gas:500000});
      const depositEndTime = await vit.depositEndTime.call();
      assert(depositEndTime.toNumber() > 0, 'depositEndTime should greater than 0 after start.');

      const closedAfter = await vit.closed.call();
      assert.equal(closedAfter, true, 'closed should be true after closed program');
    });

    it('user should not be able to close program.', async () => {
      const depositStartTime = await vit.depositStartTime.call();
      assert(depositStartTime.toNumber() > 0, 'depositStartTime should greater than 0 after start.');

      const closed = await vit.closed.call();
      assert.equal(closed, false, 'closed should be false before start program.');

      await vit.close({from: sender, gas:500000});
      const depositEndTime = await vit.depositEndTime.call();
      assert(depositEndTime.toNumber() > 0, 'depositEndTime should greater than 0 after start.');

      const closedAfter = await vit.closed.call();
      assert.equal(closedAfter, true, 'closed should be true after closed program');
    });

    // deposit Vite after closed program
    it('should not be able to deposite vite token approved after deposite window.',
      async () => {
        const closed = await vit.closed.call();
        console.log("closed:",closed);
        const depositStartTime = await vit.depositStartTime.call();
        console.log('depositStartTime',depositStartTime.toNumber());
        const depositEndTime = await vit.depositEndTime.call();
        console.log('depositEndTime',depositEndTime.toNumber());

        let viteAmount = web3.toWei(50000);
        const tokenBalanceBefore = await getTokenBalanceAsync(contractAddr);
        console.log('tokenBalanceBefore:', tokenBalanceBefore.toNumber());

        await viteToken.approve(contractAddr, viteAmount, {from: sender});

        const viteReceivedBefore = await vit.viteReceived.call();
        console.log('viteReceivedBefore:',viteReceivedBefore.toNumber());

        const senderBalance = await getTokenBalanceAsync(sender);
        console.log('senderBalance:', senderBalance.toNumber());
        
        await vit.depositVite({from: sender, gas: 5000000});

        const senderBalanceAfter = await getTokenBalanceAsync(sender);
        console.log('senderBalanceAfter:', senderBalanceAfter.toNumber());

        const viteReceivedAfter = await vit.viteReceived.call();
        console.log('viteReceivedAfter:', viteReceivedAfter.toNumber());

        const tokenBalanceAfter = await getTokenBalanceAsync(contractAddr);
        console.log('tokenBalanceAfter',tokenBalanceAfter.toNumber());
        // const ethBalanceAfter = await getEthBalanceAsync(sender);

        const tokenOfContractIncreased = 
        tokenBalanceAfter.toNumber() -
        tokenBalanceBefore.toNumber();
        assert.equal(tokenOfContractIncreased, viteAmount, 'token amount error.');
      });
  });
});






















