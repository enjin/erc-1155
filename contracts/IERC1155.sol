pragma solidity ^0.4.24;

import "./ERC165.sol";

/**
    @title ERC-1155 Multi Token Standard
    @dev Note: the ERC-165 identifier for this interface is 0x97a409d2.
 */
interface IERC1155 /*is ERC165*/ {
    /**
        @dev Either TransferSingle or TransferBatch MUST emit when tokens are transferred, including zero value transfers as well as minting or burning. This event supports single tokens.
        A `TransferSingle` event from address `0x0` signifies a minting operation. The total value transferred from address 0x0 minus the total value transferred to 0x0 may be used by clients and exchanges to be added to the "circulating supply" for a given token ID
        A `TransferSingle` event to address `0x0` signifies a burning or melting operation.
        This MUST emit a 0 value, from `0x0` to `0x0` with `_operator` assuming the role of the token creator. This can be used to define a token ID with no initial balance at the time of creation.
    */
    event TransferSingle(address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value);

    /**
        @dev Either TransferSingle or TransferBatch MUST emit when tokens are transferred, including zero value transfers as well as minting or burning. This event supports multiple _ids and _values.
        A `TransferBatch` event from address `0x0` signifies a minting operation. The total value transferred from address 0x0 minus the total value transferred to 0x0 may be used by clients and exchanges to be added to the "circulating supply" for a given token ID
        A `TransferBatch` event to address `0x0` signifies a burning or melting operation.
        This MUST emit a 0 value, from `0x0` to `0x0` with `_operator` assuming the role of the token creator. This can be used to define a token ID with no initial balance at the time of creation.
    */
    event TransferBatch(address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values);

    /**
        @dev MUST emit when an approval is updated
    */
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /**
        @dev Emits when the URI is updated for a token ID.
        The URI may point to a JSON file that conforms to the "ERC-1155 Metadata JSON Schema".
    */
    event URI(string _value, uint256 indexed _id);

    /**
        @dev Emits when the Name is updated for a token ID
    */
    event Name(string _value, uint256 indexed _id);

    /**
        @notice Transfers value amount of an _id from the _from address to the _to addresses specified. Each parameter array should be the same length, with each index correlating.
        @dev MUST emit Transfer event on success.
        Caller must have sufficient allowance by _from for the _id/_value pair, or isApprovedForAll must be true.
        Throws if `_to` is the zero address.
        Throws if `_id` is not a valid token ID.
        When transfer is complete, this function checks if `_to` is a smart contract (code size > 0). If so, it calls `onERC1155Received` on `_to` and throws if the return value is not `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`.
        @param _from    source addresses
        @param _to      target addresses
        @param _id      ID of the Token
        @param _value   transfer amounts
        @param _data    Additional data with no specified format, sent in call to `_to`
    */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes _data) external;

    /**
        @notice Send multiple types of Tokens from a 3rd party in one transfer (with safety call)
        @dev MUST emit Transfer event per id on success.
        Caller must have a sufficient allowance by _from for each of the id/value pairs.
        Throws on any error rather than return a false flag to minimize user errors.
        @param _from    Source address
        @param _to      Target address
        @param _ids     Types of Tokens
        @param _values  Transfer amounts per token type
        @param _data    Additional data with no specified format, sent in call to `_to`
    */
    function safeBatchTransferFrom(address _from, address _to, uint256[] _ids, uint256[] _values, bytes _data) external;

    /**
        @notice Get the balance of an account's Tokens
        @param _owner  The address of the token holder
        @param _id     ID of the Token
        @return        The _owner's balance of the Token type requested
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256);

    /**
        @notice Enable or disable approval for a third party ("operator") to manage all of `msg.sender`'s tokens.
        @dev MUST emit the ApprovalForAll event on success.
        @param _operator  Address to add to the set of authorized operators
        @param _approved  True if the operator is approved, false to revoke approval
    */
    function setApprovalForAll(address _operator, bool _approved) external;

    /**
        @notice Queries the approval status of an operator for a given Token and owner
        @param _owner     The owner of the Tokens
        @param _operator  Address of authorized operator
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}
