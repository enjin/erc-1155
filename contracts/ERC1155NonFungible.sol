pragma solidity ^0.4.24;

import "./ERC1155.sol";

/**
    @dev Extension to ERC1155 for Mixed Fungible and Non-Fungible Items support
    Work-in-progress
*/
contract ERC1155NonFungible is ERC1155 {

    // Use a split bit implementation.
    // Store the type in the upper 128 bits..
    uint256 constant TYPE_MASK = uint256(uint128(~0)) << 128;

    // ..and the non-fungible index in the lower 128
    uint256 constant NF_INDEX_MASK = uint128(~0);

    // The top bit is a flag to tell if this is a NFI.
    uint256 constant TYPE_NF_BIT = 1 << 255;

    mapping (uint256 => address) nfiOwners;

    // Only to make code clearer. Should not be functions
    function isNonFungible(uint256 _id) public pure returns(bool) {
        return _id & TYPE_NF_BIT == TYPE_NF_BIT;
    }
    function isFungible(uint256 _id) public pure returns(bool) {
        return _id & TYPE_NF_BIT == 0;
    }
    function getNonFungibleIndex(uint256 _id) public pure returns(uint256) {
        return _id & NF_INDEX_MASK;
    }
    function getNonFungibleBaseType(uint256 _id) public pure returns(uint256) {
        return _id & TYPE_MASK;
    }
    function isNonFungibleBaseType(uint256 _id) public pure returns(bool) {
        // A base type has the NF bit but does not have an index.
        return (_id & TYPE_NF_BIT == TYPE_NF_BIT) && (_id & NF_INDEX_MASK == 0);
    }
    function isNonFungibleItem(uint256 _id) public pure returns(bool) {
        // A base type has the NF bit but does not have an index.
        return (_id & TYPE_NF_BIT == TYPE_NF_BIT) && (_id & NF_INDEX_MASK != 0);
    }

    function ownerOf(uint256 _id) public view returns (address) {
        return nfiOwners[_id];
    }

    // retrieves an nfi id for _nfiType with a 1 based index.
    function nonFungibleByIndex(uint256 _nfiType, uint128 _index) external view returns (uint256) {
        // Needs to be a valid NFI type, not an actual NFI item
        require(isNonFungibleBaseType(_nfiType));
        require(uint256(_index) <= items[_nfiType].totalSupply);

        uint256 nfiId = _nfiType | uint256(_index);

        return nfiId;
    }

    // Allows enumeration of items owned by a specific owner
    // _index is from 0 to balanceOf(_nfiType, _owner) - 1
    function nonFungibleOfOwnerByIndex(uint256 _nfiType, address _owner, uint128 _index) external view returns (uint256) {
        // can't call this on a non-fungible item directly, only its underlying id
        require(isNonFungibleBaseType(_nfiType));
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
    function transfer(address _to, uint256[] _ids, uint256[] _values) external {
        uint256 _id;
        uint256 _value;

        for (uint256 i = 0; i < _ids.length; ++i) {
            _id = _ids[i];
            _value  = _values[i];

            if (isNonFungible(_id)) {
                require(_value == 1);
                require(nfiOwners[_id] == msg.sender);
                nfiOwners[_id] = _to;
            }

            uint256 _type = _id & TYPE_MASK;
            items[_type].balances[msg.sender] = items[_type].balances[msg.sender].sub(_value);
            items[_type].balances[_to] = _value.add(items[_type].balances[_to]);

            emit Transfer(msg.sender, msg.sender, _to, _id, _value);
        }
    }

    function transferFrom(address _from, address _to, uint256[] _ids, uint256[] _values) external {

        uint256 _id;
        uint256 _value;

        for (uint256 i = 0; i < _ids.length; ++i) {
            _id = _ids[i];
            _value  = _values[i];

            if (isNonFungible(_id)) {
                require(_value == 1);
                require(nfiOwners[_id] == _from);
                nfiOwners[_id] = _to;
            }

            if (_from != msg.sender) {
                allowances[_id][_from][msg.sender] = allowances[_id][_from][msg.sender].sub(_value);
            }

            uint256 _type = _id & TYPE_MASK;
            items[_type].balances[_from] = items[_type].balances[_from].sub(_value);
            items[_type].balances[_to] = _value.add(items[_type].balances[_to]);

            emit Transfer(msg.sender, _from, _to, _id, _value);
        }
    }

    function balanceOf(uint256 _id, address _owner) external view returns (uint256) {
        if (isNonFungibleItem(_id))
            return ownerOf(_id) == _owner ? 1 : 0;
        uint256 _type = _id & TYPE_MASK;
        return items[_type].balances[_owner];
    }

    function totalSupply(uint256 _id) external view returns (uint256) {
        // return 1 for a specific nfi, totalSupply otherwise.
        if (isNonFungibleItem(_id)) {
            // Make sure this is a valid index for the type.
            require(getNonFungibleIndex(_id) <= items[_id & TYPE_MASK].totalSupply);
            return 1;
        } else {
            return items[_id].totalSupply;
        }
    }

}
