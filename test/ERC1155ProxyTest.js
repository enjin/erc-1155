/* global artifacts, contract, it, assert */
/* eslint-disable prefer-reflect */

import expectThrow from './helpers/expectThrow';

const BigNumber = require('bignumber.js');

const ERC1155Mintable = artifacts.require('ERC1155Mintable.sol');
const ERC1155ProxyReceiver = artifacts.require('ProxyReceiver.sol');
const ERC1155ReceiverDelegate = artifacts.require('ERC1155ReceiverDelegate.sol');
const ERCXXXXReceiverDelegate = artifacts.require('ERCXXXXReceiverDelegate.sol');

const SignaturesERC1155ReceiverDelegate = "onERC1155Received(address,address,uint256,uint256,bytes)onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)setShouldReject(bool)";
const SignaturesERCXXXXReceiverDelegate = "onERCXXXXReceived(address,address,uint256,uint256,bytes)onERCXXXXBatchReceived(address,address,uint256[],uint256[],bytes)setShouldRejectXXXX(bool)setShouldRejectClash(bool)";

let user1;
let user2;
let user3;
let user4;
let mainContract;
let receiverContract;
let receiverDelegateERC1155;
let receiverDelegateERCXXXX;
let tx;

let zeroAddress = '0x0000000000000000000000000000000000000000';

let hammerId;
let swordId;
let maceId;

let idSet = [];
let quantities = [1, 1, 1];

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

function verifyURI(tx, uri, id) {
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

async function testSafeTransferFrom(operator, from, to, id, quantity, data, gasMessage='testSafeTransferFrom') {

    let preBalanceFrom = new BigNumber(await mainContract.balanceOf(from, id));
    let preBalanceTo   = new BigNumber(await mainContract.balanceOf(to, id));

    tx = await mainContract.safeTransferFrom(from, to, id, quantity, data, {from: operator});
    recordGasUsed(tx, gasMessage);
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

async function testSafeBatchTransferFrom(operator, from, to, ids, quantities, data, gasMessage='testSafeBatchTransferFrom') {

    let preBalanceFrom = [];
    let preBalanceTo   = [];

    for (let id of ids)
    {
        preBalanceFrom.push(new BigNumber(await mainContract.balanceOf(from, id)));
        preBalanceTo.push(new BigNumber(await mainContract.balanceOf(to, id)));
    }

    tx = await mainContract.safeBatchTransferFrom(from, to, ids, quantities, data, {from: operator});
    recordGasUsed(tx, gasMessage);
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

contract('ERC1155ProxyTest - tests sending 1155 items to an ERC1538 supported proxy contract.', (accounts) => {
    before(async () => {
        user1 = accounts[1];
        user2 = accounts[2];
        user3 = accounts[3];
        user4 = accounts[4];
        mainContract = await ERC1155Mintable.new();
        receiverContract = await ERC1155ProxyReceiver.new();
        receiverDelegateERC1155 = await ERC1155ReceiverDelegate.new();
        receiverDelegateERCXXXX = await ERCXXXXReceiverDelegate.new();
    });

    after(async() => {
        printGasUsed();
    });

    it('Create initial items', async () => {

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
        let hammerUri = 'https://metadata.enjincoin.io/hammer.json';
        tx = await mainContract.create(hammerQuantity, hammerUri, {from: user1});
        hammerId = verifyCreateTransfer(tx, hammerQuantity, user1);
        idSet.push(hammerId);

        // This is implementation-specific,
        // but we choose to add an URI on creation.
        // Make sure the URI event is emited correctly.
        verifyURI(tx, hammerUri, hammerId);

        let swordQuantity = 200;
        let swordUri = 'https://metadata.enjincoin.io/sword.json';
        tx = await mainContract.create(swordQuantity, swordUri, {from: user1});
        swordId = verifyCreateTransfer(tx, swordQuantity, user1);
        idSet.push(swordId);
        verifyURI(tx, swordUri, swordId);

        let maceQuantity = 1000000;
        let maceUri = 'https://metadata.enjincoin.io/mace.json';
        tx = await mainContract.create(maceQuantity, maceUri, {from: user1});
        maceId = verifyCreateTransfer(tx, maceQuantity, user1);
        idSet.push(maceId);
        verifyURI(tx, maceUri, maceId);
    });

    it('try to send item to the proxy receiver with no delegate setup', async () => {
        await expectThrow(mainContract.safeTransferFrom(user1, receiverContract.address, hammerId, 1, web3.utils.fromAscii('SomethingMeaningfull'), {from: user1}));
    });

    it('setup proxy with delegate and try same send', async () => {

        await receiverContract.updateContract(receiverDelegateERC1155.address, SignaturesERC1155ReceiverDelegate, "Adding in ERC1155ReceiverDelegate");
        await testSafeTransferFrom(user1, user1, receiverContract.address, hammerId, 1, web3.utils.fromAscii('SomethingMeaningfull'), 'testSafeTransferFrom receiver 1155');
    });

    it('remove delegate link and try batchTransfer', async () => {

        await receiverContract.updateContract(zeroAddress, SignaturesERC1155ReceiverDelegate, "Invalidating ERC1155ReceiverDelegate delegate");
        await expectThrow(mainContract.safeBatchTransferFrom(user1, receiverContract.address, idSet, quantities, web3.utils.fromAscii(''), {from: user1}));
    });

    it('restore delegate link and try batchTransfer again also testing delegate reject', async () => {

        await receiverContract.updateContract(receiverDelegateERC1155.address, SignaturesERC1155ReceiverDelegate, "Adding in ERC1155ReceiverDelegate again");

        let proxy1155Delegate = await ERC1155ReceiverDelegate.at(receiverContract.address);

        await proxy1155Delegate.setShouldReject(true);
        await expectThrow(mainContract.safeBatchTransferFrom(user1, receiverContract.address, idSet, quantities, web3.utils.fromAscii(''), {from: user1}), "onERC1155BatchReceived: transfer not accepted");
        await proxy1155Delegate.setShouldReject(false);
        await testSafeBatchTransferFrom(user1, user1, receiverContract.address, idSet, quantities, web3.utils.fromAscii(''), 'testSafeBatchTransferFrom receiver 1155')
    });

    it('show how a future delegate can clash with previous delegates data', async () => {

        await receiverContract.updateContract(receiverDelegateERCXXXX.address, SignaturesERCXXXXReceiverDelegate, "Adding in ERCXXXXReceiverDelegate");

        let proxyXXXXDelegate = await ERCXXXXReceiverDelegate.at(receiverContract.address);

        // clashing with 1155 delegate data
        await proxyXXXXDelegate.setShouldRejectClash(true);
        await expectThrow(mainContract.safeTransferFrom(user1, receiverContract.address, hammerId, 1, web3.utils.fromAscii('SomethingMeaningfull'), {from: user1}), "onERC1155Received: transfer not accepted");
        await proxyXXXXDelegate.setShouldRejectClash(false);
        await testSafeTransferFrom(user1, user1, receiverContract.address, hammerId, 1, web3.utils.fromAscii('SomethingMeaningfull'), 'testSafeTransferFrom receiver 1155');
    });

    it('show how a future delegate can set a var that doesnt clash with previous delegates data', async () => {

        let proxyXXXXDelegate = await ERCXXXXReceiverDelegate.at(receiverContract.address);

        // setting var that doesn't clash with 1155 delegate
        await proxyXXXXDelegate.setShouldRejectXXXX(true);
        await testSafeTransferFrom(user1, user1, receiverContract.address, hammerId, 1, web3.utils.fromAscii('SomethingMeaningfull'), 'testSafeTransferFrom receiver 1155');
    });

    it('attempt direct call to a delegate', async () => {
        await expectThrow(receiverDelegateERC1155.onERC1155Received(zeroAddress, zeroAddress, 0, 0, web3.utils.fromAscii('')), "Direct call: onERC1155Received");
    });
});
