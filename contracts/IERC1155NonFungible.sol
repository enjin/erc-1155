pragma solidity ^0.4.24;

interface IERC1155NonFungible {
    // Optional Functions for Non-Fungible Items
    function ownerOf(uint256 _itemId) external view returns (address);
    function itemURI(uint256 _itemId) external view returns (string);
    function itemByIndex(uint256 _itemId, uint128 _index) external view returns (uint256);
    function itemOfOwnerByIndex(uint256 _itemId, address _owner, uint128 _index) external view returns (uint256);
}