/* global artifacts, contract, it, assert */
/* eslint-disable prefer-reflect */

import expectThrow from './helpers/expectThrow';

const ERC1155Mintable = artifacts.require('ERC1155Mintable.sol');
const BigNumber = require('bignumber.js');

let user1;
let user2;
let user3;
let mainContract;

contract('ERC1155Mintable', (accounts) => {
    before(async () => {
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        mainContract = await ERC1155Mintable.new();
    });

    it('Mint initial items', async () => {
        let tx = await mainContract.mint('Hammer', 5, 'https://metadata.enjincoin.io/hammer.json', 0, 'HAM', {from: user1});
        let hammerId = await mainContract.nonce.call();
        tx = await mainContract.mint('Sword', 200, 'https://metadata.enjincoin.io/sword.json', 0, 'SRD', {from: user1});
        let swordId = await mainContract.nonce.call();
        tx = await mainContract.mint('Mace', 1000000, 'https://metadata.enjincoin.io/mace.json', 0, 'MACE', {from: user1});
        let maceId = await mainContract.nonce.call();

        assert.strictEqual(hammerId.toNumber(), 1);
        assert.strictEqual(swordId.toNumber(), 2);
        assert.strictEqual(maceId.toNumber(), 3);
    });

    it('transfer', async () => {
        let tx = await mainContract.transfer(user2, [1,2], [1,1], {from: user1});
        let hammerBalance = (await mainContract.balanceOf.call(1, user2)).toNumber();
        let swordBalance = (await mainContract.balanceOf.call(2, user2)).toNumber();
        let maceBalance = (await mainContract.balanceOf.call(3, user2)).toNumber();
        assert.strictEqual(hammerBalance, 1);
        assert.strictEqual(swordBalance, 1);
        assert.strictEqual(maceBalance, 0);
    });

    it('approve', async () => {
        let tx = await mainContract.approve(user2, [1,2], [0,0], [1,1], {from: user1});
        let hammerApproval = (await mainContract.allowance.call(1, user1, user2)).toNumber();
        let swordApproval = (await mainContract.allowance.call(2, user1, user2)).toNumber();
        let maceApproval = (await mainContract.allowance.call(3, user1, user2)).toNumber();
        assert.strictEqual(hammerApproval, 1);
        assert.strictEqual(swordApproval, 1);
        assert.strictEqual(maceApproval, 0);
    });

    it('approveSingle', async () => {
        let tx = await mainContract.approveSingle(user2, 2, 1, 2, {from: user1});
        let hammerApproval = (await mainContract.allowance.call(1, user1, user2)).toNumber();
        let swordApproval = (await mainContract.allowance.call(2, user1, user2)).toNumber();
        let maceApproval = (await mainContract.allowance.call(3, user1, user2)).toNumber();
        assert.strictEqual(hammerApproval, 1);
        assert.strictEqual(swordApproval, 2);
        assert.strictEqual(maceApproval, 0);
    });

    it('transferFrom', async () => {
        let tx = await mainContract.transferFrom(user1, user2, [1,2], [1,1], {from: user2});
        let hammerBalance = (await mainContract.balanceOf.call(1, user2)).toNumber();
        let swordBalance = (await mainContract.balanceOf.call(2, user2)).toNumber();
        let maceBalance = (await mainContract.balanceOf.call(3, user2)).toNumber();
        assert.strictEqual(hammerBalance, 2);
        assert.strictEqual(swordBalance, 2);
        assert.strictEqual(maceBalance, 0);
    });

    // Utility function to display the balances of each account.
    function printBalances(accounts) {
        console.log('    ', '== Truffle Account Balances ==');
        accounts.forEach(function (ac, i) {
            console.log('    ', i, web3.fromWei(web3.eth.getBalance(ac), 'ether').toNumber());
        });
    }
});