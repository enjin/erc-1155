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
        let hammerId = await mainContract.mint('Hammer', 5, 'https://metadata.enjincoin.io/hammer.json', 0, 'HAM', {from: user1});
        let swordId = await mainContract.mint('Sword', 200, 'https://metadata.enjincoin.io/sword.json', 0, 'SRD', {from: user1});
        let helmetId = await mainContract.mint('Helmet', 1000000, 'https://metadata.enjincoin.io/helmet.json', 0, 'HELM', {from: user1});

        assert.strictEqual(hammerId, 1);
        assert.strictEqual(swordId, 2);
        assert.strictEqual(helmetId, 3);
    });

    // Utility function to display the balances of each account.
    function printBalances(accounts) {
        console.log('    ', '== Truffle Account Balances ==');
        accounts.forEach(function (ac, i) {
            console.log('    ', i, web3.fromWei(web3.eth.getBalance(ac), 'ether').toNumber());
        });
    }
});