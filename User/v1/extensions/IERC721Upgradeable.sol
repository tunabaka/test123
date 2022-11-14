// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

interface IERC721Upgradeable is IERC165Upgradeable {

    event Transfer(address indexed from, address indexed to, address indexed tokenId);

    event Approval(address indexed owner, address indexed approved, address indexed tokenId);

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);

    function ownerOf(address tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        address tokenId
    ) external;

    function transferFrom(
        address from,
        address to,
        address tokenId
    ) external;

    function approve(address to, address tokenId) external;

    function getApproved(address tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        address tokenId,
        bytes calldata data
    ) external;
}
