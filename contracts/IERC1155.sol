pragma solidity ^0.4.24;

interface IERC1155 {
    // Events
    event Transfer(uint256 indexed _itemId, address indexed _from, address indexed _to, uint256 _value);
    event Approval(uint256 indexed _itemId, address indexed _owner, address indexed _spender, uint256 _value);

    // Required Functions
    function transfer(uint256[] _itemId, address[] _to, uint256[] _value) external returns (bool success);
    function transferFrom(uint256[] _itemId, address[] _from, address[] _to, uint256[] _value) external returns (bool success);
    function approve(uint256[] _itemId, address[] _spender, uint256[] _value) external returns (bool success);
    function increaseApproval(uint256[] _itemId, address[] _spender, uint256[] _addedValue) external returns (bool success);
    function decreaseApproval(uint256[] _itemId, address[] _spender, uint256[] _subtractedValue) external returns (bool success);

    // Required View Functions
    function totalSupply(uint256 _itemId) external view returns (uint256);
    function balanceOf(uint256 _itemId, address _owner) external view returns (uint256);
    function allowance(uint256 _itemId, address _owner, address _spender) external view returns (uint256);

    // Optional View Functions
    function name(uint256 _itemId) external view returns (string);
    function symbol(uint256 _itemId) external view returns (string);
    function decimals(uint256 _itemId) external view returns (uint8);

    // Optional Functions for Non-Fungible Items
    function ownerOf(uint256 _itemId) external view returns (address);
    function itemURI(uint256 _itemId) external view returns (string);
    function itemByIndex(uint256 _itemId, uint256 _index) external view returns (uint256);
    function itemOfOwnerByIndex(uint256 _itemId, address _owner, uint256 _index) external view returns (uint256);
}