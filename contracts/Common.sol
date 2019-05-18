pragma solidity ^0.5.0;

/**
    Note: Simple contract to use as base for const vals
*/
contract CommonConstants {

    bytes4 constant internal ERC1155_ACCEPTED = 0x4dc21a2f; // keccak256("accept_erc1155_tokens()")
    bytes4 constant internal ERC1155_BATCH_ACCEPTED = 0xac007889; // keccak256("accept_batch_erc1155_tokens()")
}
