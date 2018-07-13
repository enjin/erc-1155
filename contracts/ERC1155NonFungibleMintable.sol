pragma solidity ^0.4.24;

import "./ERC1155NonFungible.sol";

/**
    @dev Mintable form of ERC1155
    Shows how easy it is to mint new items
*/
contract ERC1155NonFungibleMintable is ERC1155NonFungible {

    mapping (uint256 => address) public minters;
    uint256 nonce;

    modifier minterOnly(uint256 _id) {
        require(minters[_id] == msg.sender);
        _;
    }

    // This function only creates the type.
    function create(
        string _name,
        string _uri,
        uint8 _decimals,
        string _symbol,
        bool _isNFI)
    external returns(uint256 _type) {

        // Store the type in the upper 128 bits
        _type = (++nonce << 128);

        // Set a flag if this is an NFI.
        if (_isNFI)
          _type = _type | TYPE_NF_BIT;

        // This will allow special access to minters.
        minters[_type] = msg.sender;

        // Setup the basic info.
        items[_type].name = _name;
        decimals[_type] = _decimals;
        symbols[_type] = _symbol;
        metadataURIs[_type] = _uri;
    }

    function mintNonFungible(uint256 _type, address[] _to) external minterOnly(_type) {

        require(isNonFungible(_type));

        // Index are 1-based.
        uint256 _startIndex = items[_type].totalSupply + 1;

        for (uint256 i = 0; i < _to.length; ++i) {

            address _dst = _to[i];
            uint256 _nfi = _type | (_startIndex + i);

            nfiOwners[_nfi] = _dst;
            items[_type].balances[_dst] = items[_type].balances[_dst].add(1);
        }

        items[_type].totalSupply = items[_type].totalSupply.add(_to.length);
    }

    function mintFungible(uint256 _type, address[] _to, uint256[] _values)
    external  {

        require(isFungible(_type));

        uint256 totalValue;
        for (uint256 i = 0; i < _to.length; ++i) {

            uint256 _value = _values[i];
            address _dst = _to[i];

            totalValue = totalValue.add(_value);

            items[_type].balances[_dst] = items[_type].balances[_dst].add(_value);
        }

        items[_type].totalSupply = items[_type].totalSupply.add(totalValue);
    }
}
