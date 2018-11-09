pragma solidity ^0.4.24;

interface IERC1155NonFungible {

    function isNonFungible(uint256 _id) external view returns (bool);
}
