pragma solidity ^0.4.24;

interface IERC1155Multicast {
    /**
        @dev Send multiple types of Tokens in one transfer from multiple sources.
        @param _from    Source addresses
        @param _to      Transfer destination addresses
        @param _ids     Types of Tokens
        @param _values  Transfer amounts
        @param _data    Additional data with no specified format, sent in call to each `_to[]` address
    */
    function safeMulticastTransferFrom(address[] _from, address[] _to, uint256[] _ids, uint256[] _values, bytes _data) external;
}
