// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../ERC1155Upgradeable.sol";

abstract contract ERC1155SupplyUpgradeable is Initializable, ERC1155Upgradeable {
    function __ERC1155Supply_init() internal initializer {
        __ERC165_init_unchained();
        __ERC1155Supply_init_unchained();
    }

    function __ERC1155Supply_init_unchained() internal onlyInitializing {}

    mapping(uint256 => uint256) private _totalSupply;
    mapping(uint256 => uint256) private _currentSupply;

    function totalSupply(
        uint256 tokenId
    )
        public
        view
        returns (uint256)
    {
        return _totalSupply[tokenId];
    }

    function _resetTotalSupply(
        uint256 tokenId
    ) internal {
        _totalSupply[tokenId] = 0;
    }

    function currentSupply(
        uint256 tokenId
    )
        public
        view
        returns (uint256)
    {
        return _currentSupply[tokenId];
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        virtual
        override
    {
        super._beforeTokenTransfer(operator, from, to, tokenIds, amounts, data);
        if (from == address(0)) {
            for (uint256 i = 0; i < tokenIds.length; ++i) {
                _totalSupply[tokenIds[i]] += amounts[i];
                _currentSupply[tokenIds[i]] += amounts[i];
            }
        }
        if (to == address(0)) {
            for (uint256 i = 0; i < tokenIds.length; ++i) {
                _currentSupply[tokenIds[i]] -= amounts[i];
            }
        }
    }

    uint256[49] private __gap;
}
