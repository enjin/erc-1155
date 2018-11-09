/* global artifacts, contract, it, assert */
/* eslint-disable prefer-reflect */

import expectThrow from './helpers/expectThrow';

const ERC1155Mintable = artifacts.require('ERC1155Mintable.sol');
const ERC1155MockReceiver = artifacts.require('ERC1155MockReceiver.sol');
const BigNumber = require('bignumber.js');

let user1;
let user2;
let user3;
let mainContract;
let receiverContract;
let tx;

let zeroAddress = '0x0000000000000000000000000000000000000000';

let hammerId;
let swordId;
let maceId;

let scope;

function verifyName(tx, id, name) {
    for (let l of tx.logs) {
        if (l.event === 'Name') {
            assert(l.args._id.eq(id));
            assert(l.args._value === name);
            return;
        }
    }
    assert(false, 'Did not find Name event');
}

function verifyURI(tx, id, uri) {
    for (let l of tx.logs) {
        if (l.event === 'URI') {
            assert(l.args._id.eq(id));
            assert(l.args._value === uri);
            return;
        }
    }
    assert(false, 'Did not find URI event');
}

function verifyTransferEvent(tx, id, from, to, quantity, operator) {
    let eventCount = 0;
    for (let l of tx.logs) {
        if (l.event === 'Transfer') {
            assert(l.args._operator === operator, "Operator mis-match");
            assert(l.args._from === from, "from mis-match");
            assert(l.args._to === to, "to mis-match");
            assert(l.args._id.eq(id), "id mis-match");
            assert(l.args._value.eq(quantity), "quantity mis-match");
            eventCount += 1;
        }
    }
    if (eventCount === 0)
        assert(false, 'Missing Transfer Event');
    else
        assert(eventCount === 1, 'Unexpected number of Transfer events');
}

async function testSafeTransferFrom(operator, from, to, id, quantity, data) {

    let preBalanceFrom = await mainContract.balanceOf(from, id);
    let preBalanceTo   = await mainContract.balanceOf(to, id);

    tx = await mainContract.safeTransferFrom(from, to, id, quantity, data, {from: operator});
    verifyTransferEvent(tx, id, from, to, quantity, operator);

    let postBalanceFrom = await mainContract.balanceOf(from, id);
    let postBalanceTo   = await mainContract.balanceOf(to, id);

    if (from !== to){
        assert.strictEqual(preBalanceFrom.sub(quantity).toNumber(),postBalanceFrom.toNumber());
        assert.strictEqual(preBalanceTo.add(quantity).toNumber(), postBalanceTo.toNumber());
    } else {
        // When from === to, just make
        assert.strictEqual(preBalanceFrom.toNumber(),postBalanceFrom.toNumber());
    }
}

function verifyTransferEvents(tx, ids, from, to, quantities, operator) {
    let totalEventCount = 0;
    for (let i; i < ids.length; ++i) {
        let eventCount = 0;
        let id = ids[i];
        let quantity = quantities[i];
        for (let l of tx.logs) {
            if (l.event === 'Transfer' &&
                l.args._operator === operator &&
                l.args._from === from &&
                l.args._to === to &&
                l.args._id.eq(id) &&
                l.args._value.eq(quantity)) {
                eventCount += 1;
                totalEventCount += 1;
            }
        }
        if (eventCount === 0)
            assert(false, 'Missing Transfer Event');
        else
            assert(eventCount === 1, 'Unexpected number of Transfer events');
    }

    assert(totalEventCount === ids.length, 'Unexpected number of Transfer events');
}

contract('ERC1155Mintable', (accounts) => {
    before(async () => {
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        mainContract = await ERC1155Mintable.new();
        receiverContract = await ERC1155MockReceiver.new();
    });

    it('Mint initial items', async () => {

        // Make sure the Transfer event respects the create or mint spec.
        // Also fetch the created id.
        function verifyCreateTransfer(tx, value, creator) {
            for (let l of tx.logs) {
                if (l.event === 'Transfer') {
                    assert(l.args._operator === creator);
                    // This signifies minting.
                    assert(l.args._from === zeroAddress);
                    if (value > 0) {
                        // Initial balance assigned to creator.
                        // Note that this is implementation specific,
                        // You could assign the initial balance to any address..
                        assert(l.args._to === creator);
                        assert(l.args._value.toNumber() === value);
                    } else {
                        // It is ok to create a new id w/o a balance.
                        // Then _to should be 0x0
                        assert(l.args._to === zeroAddress);
                        assert(l.args._value.toNumber() === 0);
                    }
                    return l.args._id;
                }
            }
            assert(false, 'Did not find initial Transfer event');
        }

        function verifyScope(tx, id) {
            for (let l of tx.logs) {
                if (l.event === 'AddToScope') {
                    assert(l.args._startId.eq(id));
                    assert(l.args._endId.eq(id));
                    return l.args._scope;
                }
            }
            assert(false, 'Did not find URI event');
        }

        let hammerQuantity = 5;
        let hammerName = 'Hammer';
        let hammerUri = 'https://metadata.enjincoin.io/hammer.json';
        tx = await mainContract.create(hammerQuantity, hammerName, hammerUri, {from: user1});
        hammerId = verifyCreateTransfer(tx, hammerQuantity, user1);

        scope = verifyScope(tx, hammerId);

        // This is implementation-specific,
        // but we choose to name and add an URI on creation.
        // Make sure the Name and URI event is emited correctly.
        verifyName(tx, hammerId, hammerName);
        verifyURI(tx, hammerId, hammerUri);

        let swordQuantity = 200;
        let swordName = 'Sword';
        let swordUri = 'https://metadata.enjincoin.io/sword.json';
        tx = await mainContract.create(swordQuantity, swordName, swordUri, {from: user1});
        swordId = verifyCreateTransfer(tx, swordQuantity, user1);
        verifyName(tx, swordId, swordName);
        verifyURI(tx, swordId, swordUri);

        let maceQuantity = 1000000;
        let macedName = 'Mace';
        let maceUri = 'https://metadata.enjincoin.io/mace.json';
        tx = await mainContract.create(maceQuantity, macedName, maceUri, {from: user1});
        maceId = verifyCreateTransfer(tx, maceQuantity, user1);
        verifyName(tx, maceId, macedName);
        verifyURI(tx, maceId, maceUri);
    });

    it('safeTransferFrom throws with no balance', async () => {
        await expectThrow(mainContract.safeTransferFrom(user2, user1, hammerId, 1, '', {from: user2}));
    });

    it('safeTransferFrom throws with invalid id', async () => {
        await expectThrow(mainContract.safeTransferFrom(user2, user1, 32, 1, '', {from: user2}));
    });

    it('safeTransferFrom throws with no approval', async () => {
        await expectThrow(mainContract.safeTransferFrom(user1, user2, hammerId, 1, '', {from: user2}));
    });

    it('safeTransferFrom throws with scoped approval for other scope', async () => {
        await mainContract.setApprovalForAll(user2, true, 0x1, {from:user1});
        await expectThrow(mainContract.safeTransferFrom(user1, user2, hammerId, 1, '', {from: user2}));
        await mainContract.setApprovalForAll(user2, false, 0x1, {from:user1});
    });

    it('safeTransferFrom throws when exceeding balance', async () => {
        await expectThrow(mainContract.safeTransferFrom(user1, user2, hammerId, 6, '', {from: user1}));
    });

    it('safeTransferFrom throws when sending to non-receiver contract', async () => {
        await expectThrow(mainContract.safeTransferFrom(user1, mainContract.address, hammerId, 1, '', {from: user1}));
    });

    it('safeTransferFrom throws if invalid response from receiver contract', async () => {
        await receiverContract.setShouldReject(true);
        await expectThrow(mainContract.safeTransferFrom(user1, receiverContract.address, hammerId, 1, 'Bob', {from: user1}));
    });

    it('safeTransferFrom from self with enough balance', async () => {
        await testSafeTransferFrom(user1, user1, user2, hammerId, 1, '');
    });

    it('safeTransferFrom to self with enough balance', async () => {
        await testSafeTransferFrom(user1, user1, user1, hammerId, 1, '');
    });

    it('safeTransferFrom zero value', async () => {
        await testSafeTransferFrom(user3, user3, user1, hammerId, 0, '');
    });

    it('safeTransferFrom from approved global operator', async () => {
        await mainContract.setApprovalForAll(user3, true, 0x0, {from:user1});
        await testSafeTransferFrom(user3, user1, user2, hammerId, 1, '');
        await mainContract.setApprovalForAll(user3, false, 0x0, {from:user1});
    });

    it('safeTransferFrom from approved scoped operator', async () => {
        await mainContract.setApprovalForAll(user3, true, scope, {from:user1});
        await testSafeTransferFrom(user3, user1, user2, hammerId, 1, '');
        await mainContract.setApprovalForAll(user3, false, scope, {from:user1});
    });

    it('safeTransferFrom to reciever contract', async () => {
        await receiverContract.setShouldReject(false);
        await testSafeTransferFrom(user1, user1, receiverContract.address, hammerId, 1, 'SomethingMeaningfull');
    });

    it('safeBatchTransferFrom', async () => {

        let idSet = [hammerId, swordId, maceId];
        let quantities = [1, 1, 1];
        // Failure cases:
        // 1- Account with insufficient balance. Must throw.
        await expectThrow(mainContract.safeBatchTransferFrom(user2, user1, idSet, quantities, '', {from: user2}));
        // 2- Invalid id is basically the same case as no balance. Must throw.
        await expectThrow(mainContract.safeBatchTransferFrom(user1, user2, [32, swordId, maceId], quantities, '', {from: user1}));
        // 3- Account with no approval cannot transfer from a 3rd party. Must throw.
        await expectThrow(mainContract.safeBatchTransferFrom(user1, user2, idSet, quantities, '', {from: user2}));
        // 4- Exceeds balance. Must throw.
        await expectThrow(mainContract.safeBatchTransferFrom(user1, user2, idSet, [6,1,1], '', {from: user1}));
        // 5- Can't send to non-reciveiver contract. Must throw.
        await expectThrow(mainContract.safeBatchTransferFrom(user1, mainContract.address, idSet, quantities, '', {from: user1}));
        // 6- Receiver contract reject. Must throw.
        await receiverContract.setShouldReject(true);
        await expectThrow(mainContract.safeBatchTransferFrom(user1, receiverContract.address, idSet, quantities, '', {from: user1}));

        async function testsafeBatchTransferFrom(operator, from, to, ids, quantities, data) {

            let preBalanceFrom = {};
            let preBalanceTo   = {};

            for (let id of ids)
            {
                preBalanceFrom.push(await mainContract.balanceOf(from, id));
                preBalanceTo.push(await mainContract.balanceOf(to, id));
            }

            tx = await mainContract.safeBatchTransferFrom(from, to, ids, quantities, data, {from: operator});
            verifyTransferEvents(tx, id, from, to, quantity, operator);

            let postBalanceFrom = {}; await mainContract.balanceOf(from, id);
            let postBalanceTo   = {}; await mainContract.balanceOf(to, id);

            for (let id of ids)
            {
                postBalanceFrom.push(await mainContract.balanceOf(from, id));
                postBalanceTo.push(await mainContract.balanceOf(to, id));
            }

            for (let i = 0; i < ids.length; ++i) {
                if (from !== to){
                    assert.strictEqual(preBalanceFrom[i].sub(quantities[i]).toNumber(), postBalanceFrom[i].toNumber());
                    assert.strictEqual(preBalanceTo[i].add(quantities[i]).toNumber(), postBalanceTo[i].toNumber());
                } else {
                    // When from === to, just make
                    assert.strictEqual(preBalanceFrom[i].toNumber(), postBalanceFrom[i].toNumber());
                }
            }
        }

        // Success cases (todo)
        // 1- From self with enough balance is ok.
        // 2- Sending to self is ok, but need balance.
        // 3- Sending zero value is ok, even with 0 balance
        // 4- From approved 3rd party.
        // 5-To receiver contract is ok if contract accept.
    });
});
