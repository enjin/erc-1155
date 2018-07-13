pragma solidity ^0.4.24;

import "./ERC1155.sol";

/**
    @dev Mintable form of ERC1155
    Shows how easy it is to mint new items
*/
contract ERC1155Mintable is ERC1155 {
    mapping (uint256 => address) public minters;
    uint256 public nonce;

    modifier minterOnly(uint256 _id) {
        require(minters[_id] == msg.sender);
        _;
    }

    function mint(string _name, uint256 _totalSupply, string _uri, uint8 _decimals, string _symbol)
    external returns(uint256 _id) {
        _id = ++nonce;
        minters[_id] = msg.sender; //

        items[_id].name = _name;
        items[_id].totalSupply = _totalSupply;
        metadataURIs[_id] = _uri;
        decimals[_id] = _decimals;
        symbols[_id] = _symbol;

        // Grant the items to the minter
        items[_id].balances[msg.sender] = _totalSupply;
    }

    function setURI(uint256 _id, string _uri) external minterOnly(_id) {
        metadataURIs[_id] = _uri;
    }
}
