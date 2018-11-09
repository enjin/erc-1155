pragma solidity ^0.4.24;

import "./ERC1155NonFungible.sol";

/**
    @dev Mintable form of ERC1155
    Shows how easy it is to mint new items
*/
contract ERC1155NonFungibleMintable is ERC1155NonFungible {

    uint256 nonce;
    mapping (uint256 => address) public creators;
    mapping (uint256 => uint256) public maxIndex;

    modifier creatorOnly(uint256 _id) {
        require(creators[_id] == msg.sender);
        _;
    }

    // This function only creates the type.
    function create(
        string _name,
        string _uri,
        bool   _isNF)
    external returns(uint256 _type) {

        // Store the type in the upper 128 bits
        _type = (++nonce << 128);

        // Set a flag if this is an NFI.
        if (_isNF)
          _type = _type | TYPE_NF_BIT;

        // This will allow special access to creators.
        creators[_type] = msg.sender;

        // emit a transfer event to help with discovery.
        emit Transfer(msg.sender, 0x0, 0x0, _type, 0);

        if (bytes(_name).length > 0)
            emit Name(_name, _type);

        if (bytes(_uri).length > 0)
            emit URI(_uri, _type);
    }

    function mintNonFungible(uint256 _type, address[] _to) external creatorOnly(_type) {

        // No need to check this is a nf type rather than an id since
        // creatorOnly() will only let a type pass through.
        require(isNonFungible(_type));

        // Index are 1-based.
        uint256 index = maxIndex[_type] + 1;

        for (uint256 i = 0; i < _to.length; ++i) {
            address dst = _to[i];
            uint256 id  = _type | index + i;

            nfOwners[id] = dst;

            // You could use base-type id to store NF type balances if you wish.
            // balances[_type][dst] = quantity.add(balances[_type][dst]);

            emit Transfer(msg.sender, 0x0, dst, id, 1);
        }

        maxIndex[_type] = _to.length.add(maxIndex[_type]);
    }

    function mintFungible(uint256 _id, address[] _to, uint256[] _quantities)  external creatorOnly(_id) {

        require(isFungible(_id));

        for (uint256 i = 0; i < _to.length; ++i) {

            uint256 quantity = _quantities[i];
            address dst   = _to[i];

            balances[_id][dst] = quantity.add(balances[_id][dst]);

            emit Transfer(msg.sender, 0x0, dst, _id, quantity);
        }
    }
}
