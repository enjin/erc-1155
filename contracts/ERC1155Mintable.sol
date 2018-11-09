pragma solidity ^0.4.24;

import "./ERC1155.sol";

/**
    @dev Mintable form of ERC1155
    Shows how easy it is to mint new items.
    Also shows an implementation of approval scopes using creator address as a key.
*/
contract ERC1155Mintable is ERC1155 {

    // id => creators
    mapping (uint256 => address) public creators;

    // A nonce to ensure we have a unique id each time we mint.
    uint256 public nonce;

    // owner => (operator => (scope => approved))
    mapping (address => mapping(address=> mapping(bytes32 => bool))) internal operatorScopeApproval;

    modifier creatorOnly(uint256 _id) {
        require(creators[_id] == msg.sender);
        _;
    }

    // Creates a new token type and assings balance to minter
    function create(uint256 _initialSupply, string _name, string _uri) external returns(uint256 _id) {
        _id = ++nonce;
        creators[_id] = msg.sender;

        balances[_id][msg.sender] = _initialSupply;

        // emit a transfer event to help with discovery.
        emit Transfer(msg.sender, 0x0, msg.sender, _id, _initialSupply);

        if (bytes(_name).length > 0)
            emit Name(_name, _id);

        if (bytes(_uri).length > 0)
            emit URI(_uri, _id);

        // Use the creator address as a scope for this id.
        emit AddToScope(bytes32(msg.sender), _id, _id);
    }

    // Batch mint tokens. Assign directly to _to[].
    function mint(uint256 _id, address[] _to, uint256[] _quantities) external creatorOnly(_id){
        for (uint256 i = 0; i < _to.length; ++i) {

            address to = _to[i];
            uint256 quantity = _quantities[i];

            // Grant the items to the caller
            balances[_id][to] = quantity.add(balances[_id][to]);

            // Emit the Transfer/Mint event.
            // the 0x0 source address implies a mint
            // It will also provide the circulating supply info.
            emit Transfer(msg.sender, 0x0, to, _id, quantity);
        }
    }

    function setURI(string _uri, uint256 _id) external creatorOnly(_id) {
        emit URI(_uri, _id);
    }

    function setName(string _name, uint256 _id) external creatorOnly(_id) {
        emit Name(_name, _id);
    }

    function setApprovalForAll(address _operator, bool _approved, bytes32 _scope) external {
        if (_scope == 0x0) {
            operatorApproval[msg.sender][_operator] = _approved;
        } else {
            operatorScopeApproval[msg.sender][_operator][_scope] = _approved;
        }
        emit ApprovalForAll(msg.sender, _operator, _approved, _scope);
    }

    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes _data) external {

        // Add scoped approval
        require(_from == msg.sender
                || operatorApproval[_from][msg.sender] == true
                || operatorScopeApproval[_from][msg.sender][bytes32(creators[_id])] == true, "Need operator approval for 3rd party transfers.");

        // Note: SafeMath will deal with insuficient funds _from
        balances[_id][_from] = balances[_id][_from].sub(_value);
        balances[_id][_to]   = _value.add(balances[_id][_to]);

        emit Transfer(msg.sender, _from, _to, _id, _value);

        // solium-disable-next-line arg-overflow
        require(_checkAndCallSafeTransfer(_from, _to, _id, _value, _data));
    }

    function safeBatchTransferFrom(address _from, address _to, uint256[] _ids, uint256[] _values, bytes _data) external {

        // Solidity does not scope variables, so declare them here.
        uint256 id;
        uint256 value;
        uint256 i;

        // Only supporting a global operator approval allows us to do only 1 check and not to touch storage to handle allowances.
        if (_from == msg.sender || operatorApproval[_from][msg.sender] == true)
        {
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
        } else {
            // Case where we need scoped approval.
            // Same code as above except for inner-loop check for scoped approval
            if (!_to.isContract()) {
                for (i = 0; i < _ids.length; ++i) {
                    id = _ids[i];
                    require(operatorScopeApproval[_from][msg.sender][bytes32(creators[id])] == true, "Need operator approval for 3rd party transfers.");
                    value = _values[i];

                    balances[id][_from] = balances[id][_from].sub(value);
                    balances[id][_to] = value.add(balances[id][_to]);

                    emit Transfer(msg.sender, _from, _to, id, value);
                }
            } else {
                for (i = 0; i < _ids.length; ++i) {
                    id = _ids[i];
                    require(operatorScopeApproval[_from][msg.sender][bytes32(creators[id])] == true, "Need operator approval for 3rd party transfers.");
                    value = _values[i];

                    balances[id][_from] = balances[id][_from].sub(value);
                    balances[id][_to] = value.add(balances[id][_to]);

                    emit Transfer(msg.sender, _from, _to, id, value);

                    require(IERC1155TokenReceiver(_to).onERC1155Received(msg.sender, _from, id, value, _data) == ERC1155_RECEIVED);
                }
            }
        }
    }

    function safeMulticastTransferFrom(address[] _from, address[] _to, uint256[] _ids, uint256[] _values, bytes _data) external {

        for (uint256 i = 0; i < _from.length; ++i) {
            address src = _from[i];
            uint256 id = _ids[i];

            require(src == msg.sender
              || operatorApproval[src][msg.sender] == true
              || operatorScopeApproval[src][msg.sender][bytes32(creators[id])] == true, "Need operator approval for 3rd party transfers.");

            address dst = _to[i];
            uint256 value = _values[i];

            balances[id][src] = balances[id][src].sub(value);
            balances[id][dst] = value.add(balances[id][dst]);

            emit Transfer(msg.sender, src, dst, id, value);

            // Note that the optional _data passed to the reciveiver is the same for all transfers.
            require(_checkAndCallSafeTransfer(src, dst, id, value, _data) == true, "Failed ERC1155TokenReceive check");
        }
    }
}
