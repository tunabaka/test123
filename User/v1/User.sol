// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "./extensions/ERC721URIStorageUpgradeable.sol";

contract User is
    Initializable,
    AccessControlEnumerableUpgradeable,
    ERC721URIStorageUpgradeable
{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    string private _baseTokenURI;

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) public initializer {
        __User_init(name, symbol, baseTokenURI);
    }

    function __User_init(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) internal onlyInitializing {
        __ERC165_init_unchained();
        __ERC721_init_unchained(name, symbol);
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __User_init_unchained(baseTokenURI);
    }

    function __User_init_unchained(
        string memory baseTokenURI
    ) internal onlyInitializing {
        _baseTokenURI = baseTokenURI;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function adminAdd(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[User.adminAdd]: must have admin role");
        grantRole(ADMIN_ROLE, account);
    }

    function isAdmin()
        private
        view
        returns (bool)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender);
    }

    function adminRemove(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[User.adminRemove]: must have admin role");
        revokeRole(ADMIN_ROLE, account);
    }

    function setTokenURI(
        address tokenId,
        string memory tokenURI
    ) public {
        require(isAdmin() || _isApprovedOrOwner(msg.sender, tokenId), "[User.setTokenURI]: must have admin role");
        _setTokenURI(tokenId, tokenURI);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenCreate(
        string memory tokenURI,
        string memory login,
        address tokenFor
    )
        public
        returns (bool)
    {
        require(isAdmin(), "[User.tokenCreate]: must have admin role");
        _mint(tokenFor, login);
        _setTokenURI(tokenFor, tokenURI);
        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlEnumerableUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
