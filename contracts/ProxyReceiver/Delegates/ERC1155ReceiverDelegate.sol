pragma solidity ^0.5.0;

import "./DelegatesStorage.sol";

///////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * @title ERC1155ReceiverDelegate
 * @dev Contract to test safe transfer behavior via proxy and delegate.
 */
///////////////////////////////////////////////////////////////////////////////////////////////////

contract ERC1155ReceiverDelegate is ProxyReceiverStorage_001_ERC1155MockReceiver {

    bytes4 constant public ERC1155_RECEIVED = 0xf23a6e61;
    bytes4 constant public ERC1155_BATCH_RECEIVED = 0xbc197c81;
    bytes4 constant public NOT_ERC1155_RECEIVED = 0xa23a6e60; // Some random value

    function setShouldReject(bool _value) external {
        require(address(this) == proxy, "Direct call: setShouldReject");

        shouldReject = _value;
    }

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
        (_operator); (_from); (_id); (_value); (_data);  // solidity, be quiet please

        require(address(this) == proxy, "Direct call: onERC1155Received");

        if (shouldReject == true) {
            return NOT_ERC1155_RECEIVED;
        } else {
            return ERC1155_RECEIVED;
        }
    }

    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4) {
        (_operator); (_from); (_ids); (_values); (_data); // solidity, be quiet please

        require(address(this) == proxy, "Direct call: onERC1155BatchReceived");

        if (shouldReject == true) {
            return NOT_ERC1155_RECEIVED;
        } else {
            return ERC1155_BATCH_RECEIVED;
        }
    }
}
