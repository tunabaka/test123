// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "./IERC721Upgradeable.sol";
import "./IERC721ReceiverUpgradeable.sol";
import "./IERC721MetadataUpgradeable.sol";

abstract contract ERC721Upgradeable is
    Initializable,
    ERC165Upgradeable,
    IERC721Upgradeable,
    IERC721MetadataUpgradeable
{
    using AddressUpgradeable for address;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(address => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(address => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Mapping from login hash to address
    mapping(string => address) private _addressByLogin;

    // Mapping from address to username
    mapping(address => string) private _loginByAddress;

    function __ERC721_init(
        string memory name_,
        string memory symbol_
    ) internal onlyInitializing {
        __ERC165_init_unchained();
        __ERC721_init_unchained(name_, symbol_);
    }

    function __ERC721_init_unchained(
        string memory name_,
        string memory symbol_
    ) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165Upgradeable) returns (bool)
    {
        return
        interfaceId == type(IERC721Upgradeable).interfaceId ||
        interfaceId == type(IERC721MetadataUpgradeable).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function balanceOf(
        address owner
    )
        public
        view
        override returns (uint256)
    {
        require(owner != address(0), "[User.balanceOf]: balance query for the zero address");
        return _balances[owner];
    }

    function ownerOf(
        address tokenId
    )
        public
        view
        override returns (address)
    {
        address owner = _owners[tokenId];
        return owner;
    }

    function name()
        public
        view
        override returns (string memory)
    {
        return _name;
    }

    function symbol()
        public
        view
        override returns (string memory)
    {
        return _symbol;
    }

    function loginByAddress(
        address tokenOwner
    )
        public
        view
        returns (string memory)
    {
        return _loginByAddress[tokenOwner];
    }

    function addressByLogin(
        string memory login
    )
        public
        view
        returns (address)
    {
        return _addressByLogin[login];
    }

    function _baseURI()
        internal
        view
        virtual
        returns (string memory)
    {
        return "";
    }

    function approve(
        address to,
        address tokenId
    )
        public
        override
    {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        require(to != owner, "[User.approve]: approval to current owner");
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "[User.approve]: approve caller is not owner nor approved for all"
        );
        _approve(to, tokenId);
    }

    function _approve(
        address to,
        address tokenId
    ) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Upgradeable.ownerOf(tokenId), to, tokenId);
    }

    function getApproved(
        address tokenId
    )
        public
        view
        override returns (address)
    {
        require(_exists(tokenId), "[User.getApproved]: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function setApprovalForAll(
        address operator,
        bool approved
    )
        public
        override
    {
        _setApprovalForAll(msg.sender, operator, approved);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function isApprovedForAll(
        address owner,
        address operator
    )
        public
        view
        override returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(
        address from,
        address to,
        address tokenId
    )
        public
        override
    {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "[User.transferFrom]: transfer caller is not owner nor approved"
        );
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        address tokenId
    )
        public
        override
    {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        address tokenId,
        bytes memory data
    )
        public
        override
    {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    function _safeTransfer(
        address from,
        address to,
        address tokenId,
        bytes memory data
    ) internal {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "[User._safeTransfer]: transfer to non ERC721Receiver implementer");
    }

    function _exists(
        address tokenId
    )
        internal
        view
        returns (bool)
    {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(
        address spender,
        address tokenId
    )
        internal
        view
        returns (bool)
    {
        require(_exists(tokenId), "[User._isApprovedOrOwner]: operator query for nonexistent token");
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _mint(
        address to,
        string memory login
    ) internal {
        require(to != address(0), "[User._mint]: mint to the zero address");
        require(!_exists(to), "[User._mint]: token already minted");
        bytes memory _loginByAddressBytes = bytes(_loginByAddress[to]);
        require(_loginByAddressBytes.length == 0, "[User._mint]: username is already taken");
        require(_addressByLogin[login] == address(0), "[User._mint]: username is already taken");
        _balances[to] += 1;
        _owners[to] = to;
        _addressByLogin[login] = to;
        _loginByAddress[to] = login;
        emit Transfer(address(0), to, to);
    }

    function _burn(
        address tokenId
    ) internal {
        address owner = ERC721Upgradeable.ownerOf(tokenId);
        // Clear approvals
        _approve(address(0), tokenId);
        _balances[owner] -= 1;
        delete _owners[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function _transfer(
        address from,
        address to,
        address tokenId
    ) internal {
        require(ERC721Upgradeable.ownerOf(tokenId) == from, "[User._transfer]: transfer of token that is not own");
        require(to != address(0), "[User._transfer]: transfer to the zero address");
        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        address tokenId,
        bytes memory _data
    )
        private
        returns (bool)
    {
        if (to.isContract()) {
            try IERC721ReceiverUpgradeable(to).onERC721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721ReceiverUpgradeable.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("[User._checkOnERC721Received]: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    uint256[50] private __gap;
}
