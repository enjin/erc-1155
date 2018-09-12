pragma solidity ^0.4.24;

interface IERC1155TokenReceiver {
    /**
        @notice Handle the receipt of an ERC1155 type
        @dev The smart contract calls this function on the recipient
        after a `safeTransfer`. This function MAY throw to revert and reject the
        transfer. Return of other than the magic value MUST result in the
        transaction being reverted
        Note: the contract address is always the message sender
        @param _operator  The address which called `safeTransferFrom` function
        @param _from      The address which previously owned the token
        @param _id        The identifier of the item being transferred
        @param _value     The amount of the item being transferred
        @param _data      Additional data with no specified format
        @return           `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
    */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes _data) external returns(bytes4);
}
