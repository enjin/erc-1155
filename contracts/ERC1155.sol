pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./IERC1155.sol";

contract ERC1155 is IERC1155 {
    using SafeMath for uint256;

    // Variables
    uint256 public index = 0;   // The last created itemId (items start at index 1)
    struct Items {
        string name;
        uint256 totalSupply;
        mapping (address => uint256) balances;
    }
    mapping (uint256 => uint8) public decimals;
    mapping (uint256 => string) public symbols;
    mapping (uint256 => mapping(address => mapping(address => uint256))) allowances;
    mapping (uint256 => Items) public items;
    mapping (uint256 => string) metadataURIs;


    // Events
    event Approval(address indexed _owner, address indexed _spender, uint256 indexed _itemId, uint256 _value);
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _itemId, uint256 _value);

    // TEMP CONSTRUCTOR - Testing purposes
    constructor() public {
        items[1].balances[msg.sender] = 1000;
        items[2].balances[msg.sender] = 1000;
        items[3].balances[msg.sender] = 1000;
    }

    function transfer(address _to, uint256[] _itemIds, uint256[] _values) external {
        uint256 _itemId;
        uint256 _value;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _value = _values[i];

            items[_itemId].balances[msg.sender] = items[_itemId].balances[msg.sender].sub(_value);
            items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);

            emit Transfer(msg.sender, _to, _itemId, _value);
        }
    }

    function transferFrom(address _from, address _to, uint256[] _itemIds, uint256[] _values) external {

        uint256 _itemId;
        uint256 _value;

        if(_from == msg.sender) {
            for (uint256 i = 0; i < _itemIds.length; ++i) {
                _itemId = _itemIds[i];
                _value = _values[i];

                items[_itemId].balances[_from] = items[_itemId].balances[_from].sub(_value);
                items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);

                emit Transfer(_from, _to, _itemId, _value);
            }
        }
        else {
            for (i = 0; i < _itemIds.length; ++i) {
                _itemId = _itemIds[i];
                _value = _values[i];

                allowances[_itemId][_from][msg.sender] = allowances[_itemId][_from][msg.sender].sub(_value);

                items[_itemId].balances[_from] = items[_itemId].balances[_from].sub(_value);
                items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);

                emit Transfer(_from, _to, _itemId, _value);
            }
        }
    }

    function approve(address _spender, uint256[] _itemIds,  uint256[] _values) external {
        uint256 _itemId;
        uint256 _value;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _value = _values[i];

            require(_value == 0 || allowances[_itemId][msg.sender][_spender] == 0);
            allowances[_itemId][msg.sender][_spender] = _value;
            emit Approval(msg.sender, _spender, _itemId, _value);
        }
    }

    function increaseApproval(address _spender, uint256[] _itemIds,  uint256[] _addedValues) external {
        uint256 _itemId;
        uint256 _addedValue;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _addedValue = _addedValues[i];

            allowances[_itemId][msg.sender][_spender] = _addedValue.add(allowances[_itemId][msg.sender][_spender]);
            emit Approval(msg.sender, _spender, _itemId, allowances[_itemId][msg.sender][_spender]);
        }
    }

    function decreaseApproval(address _spender, uint256[] _itemIds,  uint256[] _subtractedValues) external {
        uint256 _itemId;
        uint256 _subtractedValue;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _subtractedValue = _subtractedValues[i];

            uint256 oldValue = allowances[_itemId][msg.sender][_spender];
            if (_subtractedValue > oldValue) {
                allowances[_itemId][msg.sender][_spender] = 0;
            } else {
                allowances[_itemId][msg.sender][_spender] = oldValue.sub(_subtractedValue);
            }
            emit Approval(msg.sender, _spender, _itemId, allowances[_itemId][msg.sender][_spender]);
        }
    }

    // Consider this to replace increase/decreaseApproval
    function changeApproval(address _spender, uint256[] _itemIds,  int256[] _deltaValues) external {
        uint256 _itemId;
        int256  _deltaValue;
        uint256 _oldValue;
        uint256 _absDelta;

        for (uint256 i = 0; i < _itemIds.length; ++i) {
            _itemId = _itemIds[i];
            _deltaValue = _deltaValues[i];
            _oldValue = allowances[_itemId][msg.sender][_spender];

            if (_deltaValue >= 0) {
                _absDelta = uint256(_deltaValue);
                allowances[_itemId][msg.sender][_spender] = _oldValue.add(_absDelta);
            } else {
                _absDelta = uint256(-_deltaValue);
                if (_absDelta > _oldValue) {
                    allowances[_itemId][msg.sender][_spender] = 0;
                } else {
                    allowances[_itemId][msg.sender][_spender] = _oldValue.sub(_absDelta);
                }
            }
            emit Approval(msg.sender, _spender, _itemId, allowances[_itemId][msg.sender][_spender]);
        }
    }


    // Optional Single Item Functions
    function transferSingle(address _to, uint256 _itemId, uint256 _value) external {
        // Not needed. SafeMath will do the same check on .sub(_value)
        //require(_value <= items[_itemId].balances[msg.sender]);
        items[_itemId].balances[msg.sender] = items[_itemId].balances[msg.sender].sub(_value);
        items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);
        emit Transfer(msg.sender, _to, _itemId, _value);
    }

    function transferFromSingle(address _from, address _to, uint256 _itemId, uint256 _value) external {
        if(_from != msg.sender) {
            require(allowances[_itemId][_from][msg.sender] >= _value);
            allowances[_itemId][_from][msg.sender] = allowances[_itemId][_from][msg.sender].sub(_value);
        }

        items[_itemId].balances[_from] = items[_itemId].balances[_from].sub(_value);
        items[_itemId].balances[_to] = _value.add(items[_itemId].balances[_to]);

        emit Transfer(_from, _to, _itemId, _value);
    }

    function approveSingle(address _spender, uint256 _itemId, uint256 _value) external {
        // if the allowance isn't 0, it can only be updated to 0 to prevent an allowance change immediately after withdrawal
        require(_value == 0 || allowances[_itemId][msg.sender][_spender] == 0);
        allowances[_itemId][msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _itemId, _value);
    }

    function increaseApprovalSingle(address _spender, uint256 _itemId,  uint256 _addedValue) external {
        allowances[_itemId][msg.sender][_spender] = _addedValue.add(allowances[_itemId][msg.sender][_spender]);
        emit Approval(msg.sender, _spender, _itemId, allowances[_itemId][msg.sender][_spender]);
    }

    function decreaseApprovalSingle(address _spender, uint256 _itemId, uint256 _subtractedValue) external {
        uint256 oldValue = allowances[_itemId][msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowances[_itemId][msg.sender][_spender] = 0;
        } else {
            allowances[_itemId][msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, _itemId, allowances[_itemId][msg.sender][_spender]);
    }


    // Optional multicast
    function transferMulticast(address[] _to, uint256[] _itemIds, uint256[] _values) external {
        for (uint256 i = 0; i < _to.length; ++i) {
            uint256 _itemId = _itemIds[i];
            uint256 _value = _values[i];
            address _dst = _to[i];

            items[_itemId].balances[msg.sender] = items[_itemId].balances[msg.sender].sub(_value);
            items[_itemId].balances[_dst] = _value.add(items[_itemId].balances[_dst]);

            emit Transfer(msg.sender, _dst, _itemId, _value);
        }
    }

    function transferFromMulticast(address[] _from, address[] _to, uint256[] _itemIds, uint256[] _values) external {
        for (uint256 i = 0; i < _from.length; ++i) {
            uint256 _itemId = _itemIds[i];
            uint256 _value = _values[i];
            address _src = _from[i];
            address _dst = _to[i];

            if (_from[i] != msg.sender)
                allowances[_itemId][_src][msg.sender] = allowances[_itemId][_src][msg.sender].sub(_value);

            items[_itemId].balances[_src] = items[_itemId].balances[_src].sub(_value);
            items[_itemId].balances[_dst] = _value.add(items[_itemId].balances[_dst]);

            emit Transfer(_src, _dst, _itemId, _value);
        }
    }

    // Required View Functions
    function balanceOf(uint256 _itemId, address _owner) external view returns (uint256) {
        return items[_itemId].balances[_owner];
    }


    // Optional meta data view Functions
    // consider multi-lingual support for name?
    function name(uint256 _itemId) external view returns (string) {
        return items[_itemId].name;
    }

    function symbol(uint256 _itemId) external view returns (string) {
        return symbols[_itemId];
    }

    function decimals(uint256 _itemId) external view returns (uint8) {
        return decimals[_itemId];
    }

    function totalSupply(uint256 _itemId) external view returns (uint256) {
        return items[_itemId].totalSupply;
    }

    function itemURI(uint256 _itemId) external view returns (string) {
        return metadataURIs[_itemId];
    }

}
