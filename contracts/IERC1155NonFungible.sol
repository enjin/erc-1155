pragma solidity ^0.4.24;

interface IERC1155NonFungible {
    // Optional Functions for Non-Fungible Items
    function ownerOf(uint256 _id) external view returns (address);
    function nonFungibleByIndex(uint256 _id, uint128 _index) external view returns (uint256);
    function nonFungibleOfOwnerByIndex(uint256 _id, address _owner, uint128 _index) external view returns (uint256);
    function isNonFungible(uint256 _id) external view returns (bool);
}