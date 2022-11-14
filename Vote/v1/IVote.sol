// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IVote {

    struct Votes {
        uint256 positive;
        uint256 negative;
    }

    function votePositive(address actor, uint256 tokenId, uint256 votes) external;
    function voteNegative(address actor, uint256 tokenId, uint256 votes) external;
    function voteOut(address actor, uint256 tokenId, uint256 percentage) external;
    function getVotes(address actor, uint256 tokenId) external view returns (Votes memory);
    function getTotal(uint256 tokenId) external view returns (Votes memory);

}
