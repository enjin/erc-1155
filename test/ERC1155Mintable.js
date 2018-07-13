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

    it('batchTransfer', async () => {
        let tx = await mainContract.batchTransfer(user2, [1,2], [1,1], {from: user1});
        let hammerBalance = (await mainContract.balanceOf.call(1, user2)).toNumber();
        let swordBalance = (await mainContract.balanceOf.call(2, user2)).toNumber();
        let maceBalance = (await mainContract.balanceOf.call(3, user2)).toNumber();
        assert.strictEqual(hammerBalance, 1);
        assert.strictEqual(swordBalance, 1);
        assert.strictEqual(maceBalance, 0);
    });

    it('batchApprove', async () => {
        let tx = await mainContract.batchApprove(user2, [1,2], [0,0], [1,1], {from: user1});
        let hammerApproval = (await mainContract.allowance.call(1, user1, user2)).toNumber();
        let swordApproval = (await mainContract.allowance.call(2, user1, user2)).toNumber();
        let maceApproval = (await mainContract.allowance.call(3, user1, user2)).toNumber();
        assert.strictEqual(hammerApproval, 1);
        assert.strictEqual(swordApproval, 1);
        assert.strictEqual(maceApproval, 0);
    });

    it('approve', async () => {
        let tx = await mainContract.approve(user2, 2, 1, 2, {from: user1});
        let hammerApproval = (await mainContract.allowance.call(1, user1, user2)).toNumber();
        let swordApproval = (await mainContract.allowance.call(2, user1, user2)).toNumber();
        let maceApproval = (await mainContract.allowance.call(3, user1, user2)).toNumber();
        assert.strictEqual(hammerApproval, 1);
        assert.strictEqual(swordApproval, 2);
        assert.strictEqual(maceApproval, 0);
    });

    it('batchTransferFrom', async () => {
        let tx = await mainContract.batchTransferFrom(user1, user2, [1,2], [1,1], {from: user2});
        let hammerBalance = (await mainContract.balanceOf.call(1, user2)).toNumber();
        let swordBalance = (await mainContract.balanceOf.call(2, user2)).toNumber();
        let maceBalance = (await mainContract.balanceOf.call(3, user2)).toNumber();
        assert.strictEqual(hammerBalance, 2);
        assert.strictEqual(swordBalance, 2);
        assert.strictEqual(maceBalance, 0);
    });

    it('transferFrom', async () => {
        let tx = await mainContract.transferFrom(user1, user2, 2, 1, {from: user2});
        let hammerBalance = (await mainContract.balanceOf.call(1, user2)).toNumber();
        let swordBalance = (await mainContract.balanceOf.call(2, user2)).toNumber();
        let maceBalance = (await mainContract.balanceOf.call(3, user2)).toNumber();
        assert.strictEqual(hammerBalance, 2);
        assert.strictEqual(swordBalance, 3);
        assert.strictEqual(maceBalance, 0);
    });

    it('multicastTransfer', async () => {
        let tx = await mainContract.multicastTransfer([user2, user3], [2,3], [3,3], {from: user1});
        let swordBalance = (await mainContract.balanceOf.call(2, user2)).toNumber();
        let maceBalance = (await mainContract.balanceOf.call(3, user3)).toNumber();
        assert.strictEqual(swordBalance, 6);
        assert.strictEqual(maceBalance, 3);
    });

    // it('multicastApprove', async () => {
    //     let tx = await mainContract.multicastApprove([user2, user3], [1,2], [0,0], [2,2], {from: user1});
    //     tx = await mainContract.approveMulticast([user2, user3], [2,3], [0,0], [1,1], {from: user2});
    //     tx = await mainContract.approveMulticast([user2], [3], [0], [1], {from: user3});
    //
    //     let hammerApproval1 = (await mainContract.allowance.call(1, user1, user2)).toNumber();
    //     let swordApproval1 = (await mainContract.allowance.call(2, user1, user3)).toNumber();
    //     let swordApproval2 = (await mainContract.allowance.call(2, user2, user2)).toNumber();
    //     let maceApproval2 = (await mainContract.allowance.call(3, user2, user3)).toNumber();
    //
    //     assert.strictEqual(hammerApproval1, 2);
    //     assert.strictEqual(swordApproval1, 2);
    //     assert.strictEqual(swordApproval2, 1);
    //     assert.strictEqual(maceApproval2, 1);
    // });
    //
    // it('multicastTransferFrom', async () => {
    //     let tx = await mainContract.multicastTransferFrom([user1, user2], [user3, user3], [1,2], [2,1], {from: user2});
    //     tx = await mainContract.multicastTransferFrom([user1], [user3], [2], [2], {from: user3});
    //
    //     let maceApproval2 = (await mainContract.allowance.call(3, user3, user2)).toNumber();
    //     tx = await mainContract.multicastTransferFrom([user3], [user1], [3], [1], {from: user2});
    //     //tx = await mainContract.multicastTransferFrom([user1, user2], [user3, user1], [2,3], [2,1], {from: user3});
    //
    //     /*
    //     let hammerBalance1 = (await mainContract.balanceOf.call(1, user1)).toNumber();
    //     let hammerBalance2 = (await mainContract.balanceOf.call(1, user2)).toNumber();
    //     let hammerBalance3 = (await mainContract.balanceOf.call(1, user3)).toNumber();
    //
    //     let swordBalance1 = (await mainContract.balanceOf.call(2, user1)).toNumber();
    //     let swordBalance2 = (await mainContract.balanceOf.call(2, user2)).toNumber();
    //     let swordBalance3 = (await mainContract.balanceOf.call(2, user3)).toNumber();
    //
    //     let maceBalance1 = (await mainContract.balanceOf.call(3, user1)).toNumber();
    //     let maceBalance2 = (await mainContract.balanceOf.call(3, user2)).toNumber();
    //     let maceBalance3 = (await mainContract.balanceOf.call(3, user3)).toNumber();
    //
    //     assert.strictEqual(hammerBalance1, 1);
    //     assert.strictEqual(hammerBalance2, 2);
    //     assert.strictEqual(hammerBalance3, 2);
    //
    //     assert.strictEqual(swordBalance1, 193);
    //     assert.strictEqual(swordBalance2, 6);
    //     assert.strictEqual(swordBalance3, 1);
    //
    //     assert.strictEqual(maceBalance1, 999996);
    //     assert.strictEqual(maceBalance2, 1);
    //     assert.strictEqual(maceBalance3, 3);
    //     */
    // });

    // Utility function to display the balances of each account.
    function printBalances(accounts) {
        console.log('    ', '== Truffle Account Balances ==');
        accounts.forEach(function (ac, i) {
            console.log('    ', i, web3.fromWei(web3.eth.getBalance(ac), 'ether').toNumber());
        });
    }
});