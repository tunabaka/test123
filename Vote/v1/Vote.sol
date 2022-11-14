// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract Vote is Initializable, AccessControlEnumerableUpgradeable {

    uint256 constant percentageDP = 1e3; // percentage accuracy
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct Votes {
        uint256 positive;
        uint256 negative;
    }

    mapping(uint256 => Votes) private _totalVotes;
    mapping(uint256 => mapping(address => Votes)) private _votes;

    event VoteChange(address indexed account, uint256 tokenId, uint256 volume, uint256 votesPositive, uint256 votesNegative);

    function initialize() public initializer {
        __Vote_init();
    }

    function __Vote_init() internal onlyInitializing {
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __Vote_init_unchained();
    }

    function __Vote_init_unchained() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function isAdmin()
        private
        view
        returns (bool)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender);
    }

    function adminAdd(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Vote.adminAdd]: must have admin role");
        grantRole(ADMIN_ROLE, account);
    }

    function adminRemove(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Vote.adminRemove]: must have admin role");
        revokeRole(ADMIN_ROLE, account);
    }

    function votePositive(
        address actor,
        uint256 tokenId,
        uint256 votes
    ) external {
        require(isAdmin(), "[Vote.votePositive]: must have admin role");
        uint256 negative = _votes[tokenId][actor].negative;
        if (negative > 0) {
            _totalVotes[tokenId].negative -= negative;
            _votes[tokenId][actor].negative = 0;
        }
        uint256 summaryVotes = _votes[tokenId][actor].positive + negative + votes;
        _votes[tokenId][actor].positive = summaryVotes;
        _totalVotes[tokenId].positive += negative + votes;
        emit VoteChange(actor, tokenId, votes, _votes[tokenId][actor].positive, _votes[tokenId][actor].negative);
    }

    function voteNegative(
        address actor,
        uint256 tokenId,
        uint256 votes
    ) external {
        require(isAdmin(), "[Vote.voteNegative]: must have admin role");
        uint256 positive = _votes[tokenId][actor].positive;
        if (positive > 0) {
            _totalVotes[tokenId].positive -= positive;
            _votes[tokenId][actor].positive = 0;
        }
        uint256 summaryVotes = _votes[tokenId][actor].negative + positive + votes;
        _votes[tokenId][actor].negative = summaryVotes;
        _totalVotes[tokenId].negative += positive + votes;
        emit VoteChange(actor, tokenId, votes, _votes[tokenId][actor].positive, _votes[tokenId][actor].negative);
    }

    function voteOut(
        address actor,
        uint256 tokenId,
        uint256 percentage
    ) external {
        require(isAdmin(), "[Vote.voteOut]: must have admin role");
        uint256 positive = _votes[tokenId][actor].positive;
        uint256 negative = _votes[tokenId][actor].negative;
        uint256 removeValue = 0;
        if (positive > 0) {
            removeValue = percentage == 100 * percentageDP ? positive : (positive * percentage) / (100 * percentageDP);
            _votes[tokenId][actor].positive -= removeValue;
            _totalVotes[tokenId].positive -= removeValue;
        } else if (negative > 0) {
            removeValue = percentage == 100 * percentageDP ? negative : (negative * percentage) / (100 * percentageDP);
            _votes[tokenId][actor].negative -= removeValue;
            _totalVotes[tokenId].negative -= removeValue;
        }
        emit VoteChange(actor, tokenId, removeValue, _votes[tokenId][actor].positive, _votes[tokenId][actor].negative);
    }

    function getVotes(
        address actor,
        uint256 tokenId
    )
        public
        view
        returns (Votes memory)
    {
        return _votes[tokenId][actor];
    }

    function getTotal(
        uint256 tokenId
    )
        public
        view
        returns (Votes memory)
    {
        return _totalVotes[tokenId];
    }

    uint256[50] private __gap;
}
