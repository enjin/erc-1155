pragma solidity ^0.5.0;

import "./DelegatesStorage.sol";
import "../../IERC1155TokenReceiver.sol";

///////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * @title ERC1155ReceiverDelegate
 * @dev Contract to test safe transfer behavior via proxy and delegate.
 */
///////////////////////////////////////////////////////////////////////////////////////////////////

contract ERC1155ReceiverDelegate is ProxyReceiverStorage_001_ERC1155MockReceiver, IERC1155TokenReceiver {

    function setShouldReject(bool _value) external {
        require(address(this) == proxy, "Direct call: setShouldReject");

        shouldReject = _value;
    }

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
        (_operator); (_from); (_id); (_value); (_data);  // solidity, be quiet please

        require(address(this) == proxy, "Direct call: onERC1155Received");

        if (shouldReject == true) {
            revert("onERC1155Received: transfer not accepted");
        } else {
            return ERC1155_ACCEPTED;
        }
    }

    function onERC1155BatchReceived(address _operator, address _from, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external returns(bytes4) {
        (_operator); (_from); (_ids); (_values); (_data); // solidity, be quiet please

        require(address(this) == proxy, "Direct call: onERC1155BatchReceived");

        if (shouldReject == true) {
            revert("onERC1155BatchReceived: transfer not accepted");
        } else {
            return ERC1155_BATCH_ACCEPTED;
        }
    }
}
