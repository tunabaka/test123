// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IToken {

    function isValidated(uint256 tokenId) external view returns (bool);
    function isStarted(uint256 tokenId) external view returns (bool);
    function isQueued(uint256 tokenId) external view returns (bool);
    function ownerOf(uint256 tokenId) external view returns (address);
    function creatorOf(uint256 tokenId) external view returns (address);
    function exists(uint256 tokenId) external view returns (bool);

}
