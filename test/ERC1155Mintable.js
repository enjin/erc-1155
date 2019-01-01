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

let idSet = [];
let quantities = [1, 1, 1];

let gasUsed;
let gasUsedRecords = [];
let gasUsedTotal = 0;

function recordGasUsed(_tx, _label) {
    gasUsedTotal += _tx.receipt.gasUsed;
    gasUsedRecords.push(String(_label + ' \| GasUsed: ' + _tx.receipt.gasUsed).padStart(60));
}

function printGasUsed() {
    console.log('------------------------------------------------------------');
    for (let i = 0; i < gasUsedRecords.length; ++i) {
        console.log(gasUsedRecords[i]);
    }
    console.log(String("Total: " + gasUsedTotal).padStart(60));
    console.log('------------------------------------------------------------');
}

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
        if (l.event === 'TransferSingle') {
            assert(l.args._operator === operator, "Operator mis-match");
            assert(l.args._from === from, "from mis-match");
            assert(l.args._to === to, "to mis-match");
            assert(l.args._id.eq(id), "id mis-match");
            assert(l.args._value.toNumber() === quantity, "quantity mis-match");
            eventCount += 1;
        }
    }
    if (eventCount === 0)
        assert(false, 'Missing Transfer Event');
    else
        assert(eventCount === 1, 'Unexpected number of Transfer events');
}

async function testSafeTransferFrom(operator, from, to, id, quantity, data) {

    let preBalanceFrom = new BigNumber(await mainContract.balanceOf(from, id));
    let preBalanceTo   = new BigNumber(await mainContract.balanceOf(to, id));

    tx = await mainContract.safeTransferFrom(from, to, id, quantity, data, {from: operator});
    recordGasUsed(tx, 'safeTransferFrom');
    verifyTransferEvent(tx, id, from, to, quantity, operator);

    let postBalanceFrom = new BigNumber(await mainContract.balanceOf(from, id));
    let postBalanceTo   = new BigNumber(await mainContract.balanceOf(to, id));

    if (from !== to){
        assert.strictEqual(preBalanceFrom.sub(quantity).toNumber(), postBalanceFrom.toNumber());
        assert.strictEqual(preBalanceTo.add(quantity).toNumber(), postBalanceTo.toNumber());
    } else {
        // When from === to, just make sure there is no change in balance.
        assert.strictEqual(preBalanceFrom.toNumber(), postBalanceFrom.toNumber());
    }
}

function verifyTransferEvents(tx, ids, from, to, quantities, operator) {

    // Make sure we have a transfer event representing the whole transfer.
    // ToDo: Should really match the deltas, not the exact ids/events
    let totalIdCount = 0;
    for (let l of tx.logs) {
        // Match transfer _from->_to
        if (l.event === 'TransferBatch' &&
            l.args._operator === operator &&
            l.args._from === from &&
            l.args._to === to) {
            // Match payload.
            for (let j = 0; j < ids.length; ++j) {
                let id = new BigNumber(l.args._ids[j]);
                let value = new BigNumber(l.args._values[j]);
                if (id.eq(ids[j]) && value.eq(quantities[j])) {
                     ++totalIdCount;
                }
            }
         }
     }

    assert(totalIdCount === ids.length, 'Unexpected number of Transfer events found ' + totalIdCount + ' expected ' + ids.length);
}

async function testSafeBatchTransferFrom(operator, from, to, ids, quantities, data) {

    let preBalanceFrom = [];
    let preBalanceTo   = [];

    for (let id of ids)
    {
        preBalanceFrom.push(new BigNumber(await mainContract.balanceOf(from, id)));
        preBalanceTo.push(new BigNumber(await mainContract.balanceOf(to, id)));
    }

    tx = await mainContract.safeBatchTransferFrom(from, to, ids, quantities, data, {from: operator});
    recordGasUsed(tx, 'safeBatchTransferFrom');
    verifyTransferEvents(tx, ids, from, to, quantities, operator);

    // Make sure balances match the expected values
    let postBalanceFrom = [];
    let postBalanceTo   = [];

    for (let id of ids)
    {
        postBalanceFrom.push(new BigNumber(await mainContract.balanceOf(from, id)));
        postBalanceTo.push(new BigNumber(await mainContract.balanceOf(to, id)));
    }

    for (let i = 0; i < ids.length; ++i) {
        if (from !== to){
            assert.strictEqual(preBalanceFrom[i].sub(quantities[i]).toNumber(), postBalanceFrom[i].toNumber());
            assert.strictEqual(preBalanceTo[i].add(quantities[i]).toNumber(), postBalanceTo[i].toNumber());
        } else {
            assert.strictEqual(preBalanceFrom[i].toNumber(), postBalanceFrom[i].toNumber());
        }
    }
}

contract('ERC1155Mintable', (accounts) => {
    before(async () => {
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        mainContract = await ERC1155Mintable.new();
        receiverContract = await ERC1155MockReceiver.new();
    });

    after(async() => {
        printGasUsed();
    });

    it('Mint initial items', async () => {

        // Make sure the Transfer event respects the create or mint spec.
        // Also fetch the created id.
        function verifyCreateTransfer(tx, value, creator) {
            for (let l of tx.logs) {
                if (l.event === 'TransferSingle') {
                    assert(l.args._operator === creator);
                    // This signifies minting.
                    assert(l.args._from === zeroAddress);
                    if (value > 0) {
                        // Initial balance assigned to creator.
                        // Note that this is implementation specific,
                        // You could assign the initial balance to any address..
                        assert(l.args._to === creator, 'Creator mismatch');
                        assert(l.args._value.toNumber() === value, 'Value mismatch');
                    } else {
                        // It is ok to create a new id w/o a balance.
                        // Then _to should be 0x0
                        assert(l.args._to === zeroAddress);
                        assert(l.args._value.eq(0));
                    }
                    return l.args._id;
                }
            }
            assert(false, 'Did not find initial Transfer event');
        }

        let hammerQuantity = 5;
        let hammerName = 'Hammer';
        let hammerUri = 'https://metadata.enjincoin.io/hammer.json';
        tx = await mainContract.create(hammerQuantity, hammerName, hammerUri, {from: user1});
        hammerId = verifyCreateTransfer(tx, hammerQuantity, user1);
        idSet.push(hammerId);

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
        idSet.push(swordId);
        verifyName(tx, swordId, swordName);
        verifyURI(tx, swordId, swordUri);

        let maceQuantity = 1000000;
        let macedName = 'Mace';
        let maceUri = 'https://metadata.enjincoin.io/mace.json';
        tx = await mainContract.create(maceQuantity, macedName, maceUri, {from: user1});
        maceId = verifyCreateTransfer(tx, maceQuantity, user1);
        idSet.push(maceId);
        verifyName(tx, maceId, macedName);
        verifyURI(tx, maceId, maceUri);
    });

    it('safeTransferFrom throws with no balance', async () => {
        await expectThrow(mainContract.safeTransferFrom(user2, user1, hammerId, 1, web3.utils.fromAscii(''), {from: user2}));
    });

    it('safeTransferFrom throws with invalid id', async () => {
        await expectThrow(mainContract.safeTransferFrom(user2, user1, 32, 1, web3.utils.fromAscii(''), {from: user2}));
    });

    it('safeTransferFrom throws with no approval', async () => {
        await expectThrow(mainContract.safeTransferFrom(user1, user2, hammerId, 1, web3.utils.fromAscii(''), {from: user2}));
    });

    it('safeTransferFrom throws when exceeding balance', async () => {
        await expectThrow(mainContract.safeTransferFrom(user1, user2, hammerId, 6, web3.utils.fromAscii(''), {from: user1}));
    });

    it('safeTransferFrom throws when sending to non-receiver contract', async () => {
        await expectThrow(mainContract.safeTransferFrom(user1, mainContract.address, hammerId, 1, web3.utils.fromAscii(''), {from: user1}));
    });

    it('safeTransferFrom throws if invalid response from receiver contract', async () => {
        await receiverContract.setShouldReject(true);
        await expectThrow(mainContract.safeTransferFrom(user1, receiverContract.address, hammerId, 1, web3.utils.fromAscii('Bob'), {from: user1}));
    });

    it('safeTransferFrom from self with enough balance', async () => {
        await testSafeTransferFrom(user1, user1, user2, hammerId, 1, web3.utils.fromAscii(''));
        await testSafeTransferFrom(user2, user2, user1, hammerId, 1, web3.utils.fromAscii(''));
  });

    it('safeTransferFrom to self with enough balance', async () => {
        await testSafeTransferFrom(user1, user1, user1, hammerId, 1, web3.utils.fromAscii(''));
    });

    it('safeTransferFrom zero value', async () => {
        await testSafeTransferFrom(user3, user3, user1, hammerId, 0, web3.utils.fromAscii(''));
    });

    it('safeTransferFrom from approved operator', async () => {
        await mainContract.setApprovalForAll(user3, true, {from:user1});
        await testSafeTransferFrom(user3, user1, user2, hammerId, 1, web3.utils.fromAscii(''));
        await mainContract.setApprovalForAll(user3, false,{from:user1});

        // Restore state
        await mainContract.setApprovalForAll(user3, true,{ from:user2});
        await testSafeTransferFrom(user3, user2, user1, hammerId, 1, web3.utils.fromAscii(''));
        await mainContract.setApprovalForAll(user3, false, {from:user2});
    });

    it('safeTransferFrom to reciever contract', async () => {
        await receiverContract.setShouldReject(false);
        await testSafeTransferFrom(user1, user1, receiverContract.address, hammerId, 1, web3.utils.fromAscii('SomethingMeaningfull'));

        // ToDo restore state
    });

    it('safeBatchTransferFrom throws with insuficient balance', async () => {
        await expectThrow(mainContract.safeBatchTransferFrom(user2, user1, idSet, quantities, web3.utils.fromAscii(''), {from: user2}));
    });

    it('safeBatchTransferFrom throws with invalid id', async () => {
        await expectThrow(mainContract.safeBatchTransferFrom(user1, user2, [32, swordId, maceId], quantities, web3.utils.fromAscii(''), {from: user1}));
    });

    it('safeBatchTransferFrom throws with no approval', async () => {
        await expectThrow(mainContract.safeBatchTransferFrom(user1, user3, idSet, quantities, web3.utils.fromAscii(''), {from: user2}));
    });

    it('safeBatchTransferFrom throws when exceeding balance', async () => {
        await expectThrow(mainContract.safeBatchTransferFrom(user1, user2, idSet, [6,1,1], web3.utils.fromAscii(''), {from: user1}));
    });

    it('safeBatchTransferFrom throws when sending to a non-receiver contract', async () => {
        await expectThrow(mainContract.safeBatchTransferFrom(user1, mainContract.address, idSet, quantities, web3.utils.fromAscii(''), {from: user1}));
    });

    it('safeBatchTransferFrom throws with invalid reciever contract reply', async () => {
        await receiverContract.setShouldReject(true);
        await expectThrow(mainContract.safeBatchTransferFrom(user1, receiverContract.address, idSet, quantities, web3.utils.fromAscii(''), {from: user1}));
    });

    it('safeBatchTransferFrom from self with enough balance', async () => {
        await testSafeBatchTransferFrom(user1, user1, user2, idSet, quantities, web3.utils.fromAscii(''));
        await testSafeBatchTransferFrom(user2, user2, user1, idSet, quantities, web3.utils.fromAscii(''));
    });

    it('safeBatchTransferFrom to self with enough balance', async () => {
        await testSafeBatchTransferFrom(user1, user1, user1, idSet, quantities, web3.utils.fromAscii(''));
    });

    it('safeBatchTransferFrom zero quantity with zero balance', async () => {
        await testSafeBatchTransferFrom(user3, user3, user1, idSet, [0,0,0], web3.utils.fromAscii(''));
    });

    // ToDo safeBatchTransferFrom
    // From approved 3rd party.
    // From approved 3rd part with approval
    // To receiver contract is ok if contract accept.

    // ToDo safeMulticastTransferFrom tests

    // ToDo isApprovedForAll tests

    // ToDo setURI
    // ToDo setName
});
