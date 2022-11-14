// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract ERC721ValidatedUpgradable is Initializable {

    function __ERC721Validated_init() internal onlyInitializing {
        __ERC721Validated_unchained();
    }

    function __ERC721Validated_unchained() internal onlyInitializing {}

    uint256[] _unvalidated;

    event Validated(address validator, uint256 tokenId);
    event Unvalidated(address creator, uint256 tokenId, string indexed symbol);

    function _validate(
        uint256 tokenId
    ) internal {
        _removeUnvalidated(tokenId);
        emit Validated(msg.sender, tokenId);
    }

    function _unvalidate(
        uint256 tokenId,
        string memory symbol
    ) internal {
        _unvalidated.push(tokenId);
        emit Unvalidated(msg.sender, tokenId, symbol);
    }

    function _removeUnvalidated(
        uint256 tokenId
    ) internal {
        uint256 index = _unvalidated.length;
        for (uint256 i = 0; i < _unvalidated.length; i++) {
            if (_unvalidated[i] != tokenId) continue;
            index = i;
            break;
        }
        require(index < _unvalidated.length, '[Token._removeUnvalidated]: tokenId not found');
        for (uint256 i = index; i < _unvalidated.length - 1; i++) {
            _unvalidated[i] = _unvalidated[i + 1];
        }
        _unvalidated.pop();
    }

    function _getUnvalidatedCount() internal view returns (uint256) {
        return  _unvalidated.length;
    }

    function _getUnvalidated(
        uint256 index
    )
        internal
        view
        returns (uint256)
    {
        require(index < _unvalidated.length, '[Token._getUnvalidated]: token index not found');
        return  _unvalidated[index];
    }

    function _getUnvalidatedIds()
        internal
        view
        returns (uint256[] memory tokenIds)
    {
        return  _unvalidated;
    }

    function _isValidated(
        uint256 tokenId
    )
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < _unvalidated.length; i++) {
            if (_unvalidated[i] == tokenId) return false;
        }
        return true;
    }

    uint256[50] private __gap;
}
