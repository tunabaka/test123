// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IShare {

    function buyShares(uint256 tokenId, bool votePositive) external payable;
    function buySharesNewToken(uint256 tokenId, bool votePositive, address sender) external payable;

}
