// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IStaking {

    function add(address actor, uint256 tokenId, uint256 value, uint256 until) external;
    function withdraw(address actor, uint256 tokenId, uint256 value) external;
}
