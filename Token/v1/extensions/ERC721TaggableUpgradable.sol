// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract TaggableUpgradable is Initializable {

    function __ERC721Taggable_init() internal onlyInitializing {
        __ERC721Taggable_unchained();
    }

    function __ERC721Taggable_unchained() internal onlyInitializing {}

    string[] _tags;

    event TagAdded(string tag);
    event TagRemoved(string tag);

    function _tagAdd(
        string memory tag
    ) internal {
        uint256 index = _tags.length;
        bytes32 tagHash = keccak256(abi.encodePacked(tag));
        for (uint256 i = 0; i < _tags.length; i++) {
            if(keccak256(abi.encodePacked(_tags[i])) != tagHash) continue;
            index = i;
            break;
        }
        require(index == _tags.length, '[Token._tagAdd]: tag already exists');
        _tags.push(tag);
        emit TagAdded(tag);
    }

    function _tagRemove(
        string memory tag
    ) internal {
        uint256 index = _tagIndex(tag);
        require(index < _tags.length, '[Token._tagRemove]: tag not found');
        for (uint256 i = index; i < _tags.length - 1; i++) {
            _tags[i] = _tags[i + 1];
        }
        _tags.pop();
        emit TagRemoved(tag);
    }

    function _tagIndex(
        string memory tag
    )
        internal
        view
        returns (uint256)
    {
        uint256 index = _tags.length;
        bytes32 tagHash = keccak256(abi.encodePacked(tag));
        for (uint256 i = 0; i < _tags.length; i++) {
            if(keccak256(abi.encodePacked(_tags[i])) != tagHash) continue;
            index = i;
            break;
        }
        return index;
    }

    function _tagExists(
        string memory tag
    )
        internal
        view
        returns (bool)
    {
        return _tagIndex(tag) < _tags.length;
    }

    function tags()
        public
        view
        returns (string[] memory)
    {
        return _tags;
    }

    uint256[50] private __gap;
}
