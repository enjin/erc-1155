pragma solidity ^0.4.24;

interface IERC1155Metadata {
    /**
        @notice A distinct Uniform Resource Identifier (URI) for a given token
        @dev URIs are defined in RFC 3986
        @return  URI string
    */
    function uri(uint256 _id) external view returns (string);
}
