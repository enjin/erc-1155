pragma solidity ^0.5.0;

interface IERC1155NonFungible {

    function isNonFungible(uint256 _id) external view returns (bool);
}
