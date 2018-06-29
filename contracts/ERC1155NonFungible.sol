pragma solidity ^0.4.0;

import "./ERC1155.sol";

/**
    @dev Extension to ERC1155 for Non-Fungible Items support
    Work-in-progress
*/
contract ERC1155NonFungible is ERC1155 {
    uint256 constant ID_MASK = uint256(uint128(~0)) << 128;
    uint256 constant NONFUNGIBLE_IDX_MASK = uint128(~0);

    mapping (uint256 => bool) isNonFungible;
    mapping (uint256 => address) nfiOwners;

    function ownerOf(uint256 _itemId) external view returns (address) {
        return nfiOwners[_itemId];
    }

    function itemByIndex(uint256 _itemId, uint128 _index) external view returns (uint256) {
        // can't call this on a non-fungible item directly, only its underlying itemId
        require(_itemId > 0 && _itemId & NONFUNGIBLE_IDX_MASK == 0, "base");

        uint256 nfiId = _itemId.add(_index);

        // must be a valid ERC721 itemId
        require(LibItemCommon.isValidNonFungibleItemId(data, nfiId), "erc721");

        return nfiId;
    }
    function itemOfOwnerByIndex(uint256 _itemId, address _owner, uint128 _index) external view returns (uint256) {
        // can't call this on a non-fungible item directly, only its underlying itemId
        require(_itemId > 0 && _itemId & NONFUNGIBLE_IDX_MASK == 0, "base");
        require(isNonFungible[_itemId & ID_MASK]), "non-fungible");
        require(_index < balanceOf(data, _itemId, _owner), "balance");

        uint256 numToSkip = _index;
        uint256 maxIndex = items[_itemId].totalSupply;

        // rather than spending gas storing all this, loop the supply and find the item
        for (uint i = 1; i <= maxIndex; ++i) {

            uint256 nfiId = _itemId.add(i);
            address nfiOwner = nfiOwners(nfiId);

            if (nfiOwner == _owner) {
                if (numToSkip == 0) {
                    return nfiId;
                } else {
                    numToSkip = numToSkip.sub(1);
                }
            }
        }

        return 0;
    }
}
