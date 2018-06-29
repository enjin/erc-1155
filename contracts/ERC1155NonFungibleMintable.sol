pragma solidity ^0.4.24;

import "./ERC1155NonFungible.sol";

/**
    @dev Mintable form of ERC1155
    Shows how easy it is to mint new items
*/
contract ERC1155NonFungibleMintable is ERC1155NonFungible {
    mapping (uint256 => address) public minters;
    uint256 nonce;

    modifier minterOnly(uint256 _itemId) {
        require(minters[_itemId] == msg.sender);
        _;
    }

    function mint(
        string _name,
        uint256 _totalSupply,
        string _uri,
        uint8 _decimals,
        string _symbol,
        bool _isNFI)
    external returns(uint256 _itemId) {
        _itemId = ++nonce;

        if (_isNFI)
          _itemId = _itemId | NFI_BIT;

        minters[_itemId] = msg.sender;

        items[_itemId].name = _name;
        items[_itemId].totalSupply = _totalSupply;
        metadataURIs[_itemId] = _uri;
        decimals[_itemId] = _decimals;
        symbols[_itemId] = _symbol;

        items[_itemId].balances[msg.sender] = _totalSupply;
    }

    // Each NFI needs to be transfered indiviually,
    // This function allows the minter to do the initial transfer
    function transferMintedNFI(uint256 _nfiType, address[] _to) external minterOnly(_itemId) {
        items[_itemId].balances[msg.sender] = items[_itemId].balances[msg.sender].sub(_to.length);

        for (uint256 i = 0; i < _to.length; ++i) {
            require(nfiOwners[_nfi] == 0 || nfiOwners[_nfi] == msg.sender);
            address _dst =  _to[i];
            nfiOwners[_nfi] = _dst;
            items[_itemId].balances[_dst] = items[_itemId].balances[_dst].add(1);
        }
    }
}
