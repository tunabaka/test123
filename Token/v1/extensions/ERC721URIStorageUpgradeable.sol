// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/**
 * @dev ERC721 token with storage based token URI management.
 */

abstract contract ERC721URIStorageUpgradeable is Initializable, ERC721Upgradeable {

    function __ERC721URIStorage_init() internal onlyInitializing {
        __ERC165_init_unchained();
        __ERC721URIStorage_init_unchained();
    }

    function __ERC721URIStorage_init_unchained() internal onlyInitializing {
    }

    using StringsUpgradeable for uint256;

    // mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    mapping(string => uint256) private _existingURIs;

    event TokenURIChanged(uint256 indexed tokenId, string tokenURI);

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */

    function tokenURIById(
        uint256 tokenId
    )
        public
        view
        returns (string memory)
    {
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();
        return string(abi.encodePacked(base, _tokenURI));
    }

    function tokenIndexByURI(
        string memory tokenURI
    )
        public
        view
        returns (int256)
    {
        if (_existingURIs[tokenURI] <= 0) return -1;
        return int256(_existingURIs[tokenURI] - 1);
    }

    function tokenURIExists(
        string memory URI
    )
        public
        view
        returns (bool)
    {
        return _existingURIs[URI] > 0;
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */

    function _setTokenURI(
        uint256 tokenId,
        string memory tokenURI,
        bool isInitial
    ) internal {
        require(_exists(tokenId), "[Token._setTokenURI]: URI set of nonexistent token");
        string memory uri = _tokenURIs[tokenId];
        delete _existingURIs[uri];
        _tokenURIs[tokenId] = tokenURI;
        _existingURIs[tokenURI] = tokenId + 1;
        if (!isInitial) emit TokenURIChanged(tokenId, tokenURI);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */

    function _burnNFT(
        uint256 tokenId
    ) internal {
        super._burn(tokenId);
    }

    uint256[50] private __gap;
}
