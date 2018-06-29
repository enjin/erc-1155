pragma solidity ^0.4.24;

import "./ERC1155.sol";

/**
    @dev Extension to ERC1155 for Non-Fungible Items support
    Work-in-progress
*/
contract ERC1155NonFungible is ERC1155 {

    // Use a split bit implementation.
    // Store the metaid in the upper 128 bits..
    uint256 constant TYPE_MASK = uint256(uint128(~0)) << 128;
    // ..and the index in the lower 128
    uint256 constant NFI_INDEX_MASK = uint128(~0);
    uint256 constant NFI_BIT = 1 << 255;

    mapping (uint256 => address) nfiOwners;

    function ownerOf(uint256 _itemId) public view returns (address) {
        return nfiOwners[_itemId];
    }

    // retrieves an nfi itemId for _nfiType with a 1 based index.
    function itemByIndex(uint256 _nfiType, uint128 _index) external view returns (uint256) {
        // Needs to be a valid NFI type, not an actual NFI item
        require(_nfiType & TYPE_MASK == 0 && _nfiType & NFI_BIT  != 0);
        require(uint256(_index) <= items[_nfiType].totalSupply);

        uint256 nfiId = _nfiType | uint256(_index);

        return nfiId;
    }

    // Allows enumeration of items owned by a specific owner
    function itemOfOwnerByIndex(uint256 _nfiType, address _owner, uint128 _index) external view returns (uint256) {
        // can't call this on a non-fungible item directly, only its underlying itemId
        require(_nfiType & TYPE_MASK == 0 && _nfiType & NFI_BIT  != 0);
        require(_index < items[_nfiType].balances[_owner]);

        uint256 _numToSkip = _index;
        uint256 _maxIndex  = items[_nfiType].totalSupply;

        // rather than spending gas storing all this, loop the supply and find the item
        for (uint256 i = 1; i <= _maxIndex; ++i) {

            uint256 _nfiId    = _nfiType | i;
            address _nfiOwner = nfiOwners[_nfiId];

            if (_nfiOwner == _owner) {
                if (_numToSkip == 0) {
                    return _nfiId;
                } else {
                    _numToSkip = _numToSkip.sub(1);
                }
            }
        }

        return 0;
    }

    // overides
    function transfer(address _to, uint256[] _itemIds, uint256[] _values) external {
        uint256 _itemId;
        uint256 _value;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _value = _values[i];

            if (_itemId & NFI_BIT != 0) {
                uint256 _nfiType = _itemId & TYPE_MASK;
                require(nfiOwners[_itemId] == msg.sender);
                nfiOwners[_itemId] = _to;
                items[_nfiType].balances[msg.sender] = items[_nfiType].balances[msg.sender].sub(1);
                items[_nfiType].balances[_to] = items[_nfiType].balances[_to].add(1);
            } else {
                items[_itemId].balances[msg.sender] = items[_itemId].balances[msg.sender].sub(_value);
                items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);
            }

            emit Transfer(msg.sender, _to, _itemId, _value);
        }
    }

    function transferFrom(address _from, address _to, uint256[] _itemIds, uint256[] _values) external {

        uint256 _itemId;
        uint256 _value;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _value = _values[i];

            if (_itemId & NFI_BIT != 0) {
                require(_value == 1);
                uint256 _nfiType = _itemId & TYPE_MASK;
                require(nfiOwners[_itemId] == _from);
                nfiOwners[_itemId] = _to;
                items[_nfiType].balances[_from] = items[_nfiType].balances[_from].sub(1);
                items[_nfiType].balances[_to] = items[_nfiType].balances[_to].add(1);
            } else {
                items[_itemId].balances[_from] = items[_itemId].balances[_from].sub(_value);
                items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);
            }

            if (_from != msg.sender) {
                allowances[_itemId][_from][msg.sender] = allowances[_itemId][_from][msg.sender].sub(_value);
            }

            emit Transfer(_from, _to, _itemId, _value);
        }
    }

    function balanceOf(uint256 _itemId, address _owner) external view returns (uint256) {
        uint256 _type = _itemId & TYPE_MASK;
        return items[_type].balances[_owner];
    }
}
