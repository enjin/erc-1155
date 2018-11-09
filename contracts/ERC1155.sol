pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./Address.sol";
import "./IERC1155TokenReceiver.sol";
import "./IERC1155.sol";
import "./ERC165.sol";

// A basic implementation of ERC1155.
// Supports core 1155
contract ERC1155 is IERC1155, ERC165
{
    using SafeMath for uint256;
    using Address for address;

    bytes4 constant public ERC1155_RECEIVED = 0xf23a6e61;

    // id => (owner => balance)
    mapping (uint256 => mapping(address => uint256)) internal balances;

    // owner => (operator => approved)
    mapping (address => mapping(address => bool)) internal operatorApproval;

/////////////////////////////////////////// ERC165 //////////////////////////////////////////////

    function supportsInterface(bytes4 _interfaceId)
    external
    view
    returns (bool) {
         // ToDo recalc interface.
         if (_interfaceId == 0) {
            return true;
         }

         return false;
    }

/////////////////////////////////////////// ERC1155 //////////////////////////////////////////////

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
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes _data) external {

        require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval for 3rd party transfers.");

        // Note: SafeMath will deal with insuficient funds _from
        balances[_id][_from] = balances[_id][_from].sub(_value);
        balances[_id][_to]   = _value.add(balances[_id][_to]);

        emit Transfer(msg.sender, _from, _to, _id, _value);

        // solium-disable-next-line arg-overflow
        require(_checkAndCallSafeTransfer(_from, _to, _id, _value, _data));
    }

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
    function safeBatchTransferFrom(address _from, address _to, uint256[] _ids, uint256[] _values, bytes _data) external {

        // Solidity does not scope variables, so declare them here.
        uint256 id;
        uint256 value;
        uint256 i;

        // Only supporting a global operator approval allows us to do only 1 check and not to touch storage to handle allowances.
        require(_from == msg.sender || operatorApproval[_from][msg.sender] == true, "Need operator approval for 3rd party transfers.");

        // Optimize for when _to is not a contract.
        // This makes safe transfer virtually the same cost as a regular transfer
        // when not sending to a contract.
        if (!_to.isContract()) {
            // We assume _ids.length == _values.length
            // we don't check since out of bound access will throw.
            for (i = 0; i < _ids.length; ++i) {
                id = _ids[i];
                value = _values[i];

                balances[id][_from] = balances[id][_from].sub(value);
                balances[id][_to] = value.add(balances[id][_to]);

                emit Transfer(msg.sender, _from, _to, id, value);
            }
        } else {
            for (i = 0; i < _ids.length; ++i) {
                id = _ids[i];
                value = _values[i];

                balances[id][_from] = balances[id][_from].sub(value);
                balances[id][_to] = value.add(balances[id][_to]);

                emit Transfer(msg.sender, _from, _to, id, value);

                // We know _to is a contract.
                // Call onERC1155Received and throw if we don't get ERC1155_RECEIVED,
                // as per the standard requirement. This allows the receiving contract to perform actions
                require(IERC1155TokenReceiver(_to).onERC1155Received(msg.sender, _from, id, value, _data) == ERC1155_RECEIVED);
            }
        }
    }

    /**
        @dev Send multiple types of Tokens in one transfer from multiple sources.
             This function allows arbitrary trades to be performed with N parties.
             A common pattern is a 3 party tradewith 2 parties exchanging tokens,
             plus a 3rd party operator collecting some fee to manage the trade)
        @param _from    Source addresses
        @param _to      Transfer destination addresses
        @param _ids     Types of Tokens
        @param _values  Transfer amounts
        @param _data    Additional data with no specified format, sent in call to each `_to[]` address
    */
    function safeMulticastTransferFrom(address[] _from, address[] _to, uint256[] _ids, uint256[] _values, bytes _data) external {

        for (uint256 i = 0; i < _from.length; ++i) {
            address src = _from[i];
            // Unlike safeBatchTransferFrom, we need to check inside the loop since src can change.
            require(src == msg.sender || operatorApproval[src][msg.sender] == true, "Need operator approval for 3rd party transfers.");

            address dst = _to[i];
            uint256 id = _ids[i];
            uint256 value = _values[i];

            balances[id][src] = balances[id][src].sub(value);
            balances[id][dst] = value.add(balances[id][dst]);

            emit Transfer(msg.sender, src, dst, id, value);

            // Note that the optional _data passed to the reciveiver is the same for all transfers.
            require(_checkAndCallSafeTransfer(src, dst, id, value, _data) == true, "Failed ERC1155TokenReceive check");
        }
    }

    /**
        @notice Get the balance of an account's Tokens
        @param _owner  The address of the token holder
        @param _id     ID of the Token
        @return        The _owner's balance of the Token type requested
     */
    function balanceOf(address _owner, uint256 _id) external view returns (uint256) {
        // The balance of any account can be calculated from the Transfer events history.
        // However, since we need to keep the balances to validate transfer request,
        // there is no extra cost to also privide a querry function.
        return balances[_id][_owner];
    }

    /**
        @notice Enable or disable approval for a third party ("operator") to manage all of `msg.sender`'s tokens.
        @dev MUST emit the ApprovalForAll event on success.
        @param _operator  Address to add to the set of authorized operators
        @param _approved  True if the operator is approved, false to revoke approval
        @param _scope     Optional argument allowing to scope approval to a set of ids. Passing a value of 0
                          gives approval for all ids. MUST throw if the _scope value is not a supported scope.
    */
    function setApprovalForAll(address _operator, bool _approved, bytes32 _scope) external {
       // Only supporting global scope for this implementation.
        require(_scope == 0x0);
        operatorApproval[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved, _scope);
    }

    /**
        @notice Queries the approval status of an operator for a given Token and owner
        @param _owner     The owner of the Tokens
        @param _operator  Address of authorized operator
        @param _scope     A scope of 0 refers to all IDs
        @return           True if the operator is approved, false if not
    */
    function isApprovedForAll(address _owner, address _operator, bytes32 _scope) external view returns (bool) {
        require(_scope == 0x0);
        return operatorApproval[_owner][_operator];
    }

////////////////////////////////////////// INTERNAL //////////////////////////////////////////////

    function _checkAndCallSafeTransfer(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes _data
    )
    internal
    returns (bool)
    {
        if (!_to.isContract()) {
            return true;
        }
        bytes4 retval = IERC1155TokenReceiver(_to).onERC1155Received(
            msg.sender, _from, _id, _value, _data);
        return (retval == ERC1155_RECEIVED);
    }


}
