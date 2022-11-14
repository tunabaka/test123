// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IERC721ReceiverUpgradeable {
    function onERC721Received(
        address operator,
        address from,
        address tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
