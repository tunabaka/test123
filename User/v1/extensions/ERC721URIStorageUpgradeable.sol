// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ERC721Upgradeable.sol";

contract ERC721URIStorageUpgradeable is Initializable, ERC721Upgradeable {

    function __ERC721URIStorage_init() internal onlyInitializing {
        __ERC165_init_unchained();
        __ERC721URIStorage_init_unchained();
    }

    function __ERC721URIStorage_init_unchained() internal onlyInitializing {}

    event UserTokenURIChanged(address indexed tokenId, string tokenURI);

    // mapping for token URIs
    mapping(address => string) private _tokenURIs;

    function _setTokenURI(
        address tokenId,
        string memory tokenURI_
    ) internal virtual {
        require(_exists(tokenId), "[User._setTokenURI]: URI set of nonexistent token");
        _tokenURIs[tokenId] = tokenURI_;
        emit UserTokenURIChanged(tokenId, tokenURI_);
    }

    function tokenURI(
        address tokenId
    )
        external
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) return '';
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory baseURI = _baseURI();
        if (bytes(baseURI).length == 0) {
            return _tokenURI;
        } else {
            return string(abi.encodePacked(baseURI, _tokenURI));
        }
    }

    uint256[50] private __gap;
}
