pragma solidity ^0.4.24;

import "./ERC1155.sol";

/**
    @dev Mintable form of ERC1155
    Shows how easy it is to mint new items
*/
contract ERC1155Mintable is ERC1155 {

    // id => creators
    mapping (uint256 => address) public creators;
    // A nonce to ensure we have a unique id each time we mint.
    uint256 public nonce;

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
}
