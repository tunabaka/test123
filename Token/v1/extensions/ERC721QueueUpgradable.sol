// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract ERC721QueueUpgradable is Initializable {

    uint256 MAX_INT;

    function __ERC721Queue_init() internal onlyInitializing {
        __ERC721Queue_unchained();
    }

    function __ERC721Queue_unchained() internal onlyInitializing {
        MAX_INT = 2 ** 256 - 1;
    }

    struct QueueItem {
        uint256 tokenId;
        uint256 startTime;
    }

    QueueItem[] _queue;

    event Queued(uint256 tokenId, uint256 startTime);
    event QueueStarted(uint256[] tokenIds, uint256 startedAt);

    // Mapping from token ID to boolean
    mapping(uint256 => bool) private _queued;
    mapping(uint256 => uint256) internal _startedAt;

    function _queueGet()
        internal
        view
        returns (QueueItem[] memory tokens)
    {
        return _queue;
    }

    function _queueAdd(
        uint256 tokenId,
        uint256 startTime
    ) internal {
        // unique is checked in validation result
        _queue.push(QueueItem({
          tokenId: tokenId,
          startTime: startTime
        }));
        _queued[tokenId] = true;
        emit Queued(tokenId, startTime);
    }

    function _startTokens(
        uint256[] memory tokenIds
    ) internal {
        uint256 startedCounter = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (_removeFromQueue(tokenIds[i], true)) {
                startedCounter++;
            } else {
                tokenIds[i] = MAX_INT;
            }
        }
        uint256[] memory startedIds = new uint256[](startedCounter);
        uint256 counter = 0;
        if (startedCounter == 0) return;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIds[i] == MAX_INT) continue;
            startedIds[counter++] = tokenIds[i];
        }
        emit QueueStarted(startedIds, block.timestamp);
    }

    function _removeFromQueue(
        uint256 tokenId,
        bool isStart
    )
        internal
        returns (bool)
    {
        int256 index = -1;
        for (uint256 i = 0; i < _queue.length; i++) {
            if (_queue[i].tokenId != tokenId) continue;
            index = int256(i);
            break;
        }
        if (index < 0) return false;
        if (isStart) _startedAt[tokenId] = _queue[uint256(index)].startTime;
        for (uint256 i = uint256(index); i < _queue.length - 1; i++) {
            _queue[i] = _queue[i + 1];
        }
        _queue.pop();
        delete _queued[tokenId];
        return true;
    }

    function _getQueueLength()
        internal
        view
        returns (uint256)
    {
        return  _queue.length;
    }

    function _isQueued(
        uint256 tokenId
    )
        internal
        view
        returns (bool)
    {
        return  _queued[tokenId];
    }

    function _queuedItemByTokenId(
        uint256 tokenId
    )
        internal
        view
        returns (QueueItem memory queueItem)
    {
        for (uint256 i = 0; i < _queue.length; i++) {
            if (_queue[i].tokenId == tokenId) return _queue[i];
        }
        return QueueItem({
            tokenId: MAX_INT,
            startTime: 0
        });
    }

    uint256[50] private __gap;
}
