pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./IERC1155.sol";

contract ERC1155 is IERC1155, IERC1155Extended, IERC1155BatchTransfer, IERC1155BatchTransferExtended {
    using SafeMath for uint256;

    // Variables
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


/////////////////////////////////////////// IERC1155 //////////////////////////////////////////////

    // Events
    event Approval(address indexed _owner, address indexed _spender, uint256 indexed _id, uint256 _oldValue, uint256 _value);
    event Transfer(address _spender, address indexed _from, address indexed _to, uint256 indexed _id, uint256 _value);

    function transferFrom(address _from, address _to, uint256 _id, uint256 _value) external {
        if(_from != msg.sender) {
            require(allowances[_id][_from][msg.sender] >= _value);
            allowances[_id][_from][msg.sender] = allowances[_id][_from][msg.sender].sub(_value);
        }

        items[_id].balances[_from] = items[_id].balances[_from].sub(_value);
        items[_id].balances[_to] = _value.add(items[_id].balances[_to]);

        emit Transfer(msg.sender, _from, _to, _id, _value);
    }

    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes _data) external {
        revert('TBD');
    }

    function approve(address _spender, uint256 _id, uint256 _currentValue, uint256 _value) external {
        // if the allowance isn't 0, it can only be updated to 0 to prevent an allowance change immediately after withdrawal
        require(_value == 0 || allowances[_id][msg.sender][_spender] == _currentValue);
        allowances[_id][msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _id, _currentValue, _value);
    }

    function balanceOf(uint256 _id, address _owner) external view returns (uint256) {
        return items[_id].balances[_owner];
    }

    function allowance(uint256 _id, address _owner, address _spender) external view returns (uint256) {
        return allowances[_id][_owner][_spender];
    }

/////////////////////////////////////// IERC1155Extended //////////////////////////////////////////

    function transfer(address _to, uint256 _id, uint256 _value) external {
        // Not needed. SafeMath will do the same check on .sub(_value)
        //require(_value <= items[_id].balances[msg.sender]);
        items[_id].balances[msg.sender] = items[_id].balances[msg.sender].sub(_value);
        items[_id].balances[_to] = _value.add(items[_id].balances[_to]);
        emit Transfer(msg.sender, msg.sender, _to, _id, _value);
    }

    function safeTransfer(address _to, uint256 _id, uint256 _value, bytes _data) external {
        revert('TBD');
    }

//////////////////////////////////// IERC1155BatchTransfer ////////////////////////////////////////

    function batchTransferFrom(address _from, address _to, uint256[] _ids, uint256[] _values) external {
        uint256 _id;
        uint256 _value;

        if(_from == msg.sender) {
            for (uint256 i = 0; i < _ids.length; ++i) {
                _id = _ids[i];
                _value = _values[i];

                items[_id].balances[_from] = items[_id].balances[_from].sub(_value);
                items[_id].balances[_to] = _value.add(items[_id].balances[_to]);

                emit Transfer(msg.sender, _from, _to, _id, _value);
            }
        }
        else {
            for (i = 0; i < _ids.length; ++i) {
                _id = _ids[i];
                _value = _values[i];

                allowances[_id][_from][msg.sender] = allowances[_id][_from][msg.sender].sub(_value);

                items[_id].balances[_from] = items[_id].balances[_from].sub(_value);
                items[_id].balances[_to] = _value.add(items[_id].balances[_to]);

                emit Transfer(msg.sender, _from, _to, _id, _value);
            }
        }
    }

    function safeBatchTransferFrom(address _from, address _to, uint256[] _ids, uint256[] _values, bytes _data) external {
        revert('TBD');
    }

    function batchApprove(address _spender, uint256[] _ids,  uint256[] _currentValues, uint256[] _values) external {
        uint256 _id;
        uint256 _value;

        for (uint256 i = 0; i < _ids.length; ++i) {
            _id = _ids[i];
            _value = _values[i];

            require(_value == 0 || allowances[_id][msg.sender][_spender] == _currentValues[i]);
            allowances[_id][msg.sender][_spender] = _value;
            emit Approval(msg.sender, _spender, _id, _currentValues[i], _value);
        }
    }

//////////////////////////////// IERC1155BatchTransferExtended ////////////////////////////////////

    function batchTransfer(address _to, uint256[] _ids, uint256[] _values) external {
        uint256 _id;
        uint256 _value;

        for (uint256 i = 0; i < _ids.length; ++i) {
            _id = _ids[i];
            _value = _values[i];

            items[_id].balances[msg.sender] = items[_id].balances[msg.sender].sub(_value);
            items[_id].balances[_to] = _value.add(items[_id].balances[_to]);

            emit Transfer(msg.sender, msg.sender, _to, _id, _value);
        }
    }

    function safeBatchTransfer(address _to, uint256[] _ids, uint256[] _values, bytes _data) external {
        revert('TBD');
    }

//////////////////////////////// IERC1155BatchTransferExtended ////////////////////////////////////

    // Optional meta data view Functions
    // consider multi-lingual support for name?
    function name(uint256 _id) external view returns (string) {
        return items[_id].name;
    }

    function symbol(uint256 _id) external view returns (string) {
        return symbols[_id];
    }

    function decimals(uint256 _id) external view returns (uint8) {
        return decimals[_id];
    }

    function totalSupply(uint256 _id) external view returns (uint256) {
        return items[_id].totalSupply;
    }

    function uri(uint256 _id) external view returns (string) {
        return metadataURIs[_id];
    }

////////////////////////////////////////// OPTIONALS //////////////////////////////////////////////


    function multicastTransfer(address[] _to, uint256[] _ids, uint256[] _values) external {
        for (uint256 i = 0; i < _to.length; ++i) {
            uint256 _id = _ids[i];
            uint256 _value = _values[i];
            address _dst = _to[i];

            items[_id].balances[msg.sender] = items[_id].balances[msg.sender].sub(_value);
            items[_id].balances[_dst] = _value.add(items[_id].balances[_dst]);

            emit Transfer(msg.sender, msg.sender, _dst, _id, _value);
        }
    }

    function safeMulticastTransfer(address[] _to, uint256[] _ids, uint256[] _values, bytes _data) external {
        revert('TBD');
    }
}
