// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

contract ERC1155Upgradeable is Initializable, ERC165Upgradeable, IERC1155Upgradeable {
    using AddressUpgradeable for address;

    struct structUser {
        uint256 balance;
        uint256 index;
        bool exists;
    }
    address[] public addressIndexes;

    mapping(uint256 => mapping(address => structUser)) private _users;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    function __ERC1155_init() internal initializer {
        __ERC165_init_unchained();
        __ERC1155_init_unchained();
    }

    function __ERC1155_init_unchained() internal onlyInitializing {}

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC165Upgradeable, IERC165Upgradeable) returns (bool)
    {
        return interfaceId == type(IERC1155Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function getAddresses()
        public
        view
        returns (address[] memory)
    {
        return addressIndexes;
    }

    function getTotalUsers()
        public
        view
        returns (uint256)
    {
        return addressIndexes.length;
    }

    function balanceOf(
        address account,
        uint256 id
    )
        public
        view
        override returns (uint256)
    {
        require(account != address(0), "[Share.balanceOf]: balance query for the zero address");
        return _users[id][account].balance;
    }

    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    )
        public
        view
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "[Share.balanceOfBatch]: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }
        return batchBalances;
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

    function isApprovedForAll(
        address account,
        address operator
    )
        public
        view
        override
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    )
        public
        override
    {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "[Share.safeTransferFrom]: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        public
        override
    {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "[Share.safeBatchTransferFrom]: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        address operator = msg.sender;
        _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);
        uint256 fromBalance = _users[id][from].balance;
        require(fromBalance >= amount, "[Share._safeTransferFrom]: insufficient balance for transfer");
        unchecked { _users[id][from].balance = fromBalance - amount; }
        _users[id][to].balance += amount;
        emit TransferSingle(operator, from, to, id, amount);
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(ids.length == amounts.length, "[Share._safeBatchTransferFrom]: ids and amounts length mismatch");
        address operator = msg.sender;
        _beforeTokenTransfer(operator, from, to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            uint256 fromBalance = _users[id][from].balance;
            require(fromBalance >= amount, "[Share._safeBatchTransferFrom]: insufficient balance for transfer");
            unchecked { _users[id][from].balance = fromBalance - amount; }
            _users[id][to].balance += amount;
        }
        emit TransferBatch(operator, from, to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(to != address(0), "[Share._mint]: mint to the zero address");
        address operator = msg.sender;
        _beforeTokenTransfer(operator, address(0), to, _asSingletonArray(id), _asSingletonArray(amount), data);
        if (_users[id][to].exists) {
            _users[id][to].balance += amount;
        } else {
            addressIndexes.push(to);
            _users[id][to].balance = amount;
            _users[id][to].index = addressIndexes.length - 1;
            _users[id][to].exists = true;
        }
        emit TransferSingle(operator, address(0), to, id, amount);
        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal {
        require(owner != operator, "[Share._setApprovalForAll]: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    )
        internal
        virtual
    {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155Received.selector) {
                    revert("[Share._doSafeTransferAcceptanceCheck]: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("[Share._doSafeTransferAcceptanceCheck]: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155ReceiverUpgradeable(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector) {
                    revert("[Share._doSafeBatchTransferAcceptanceCheck]: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("[Share._doSafeBatchTransferAcceptanceCheck]: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(
        uint256 element
    )
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory array = new uint256[](1);
        array[0] = element;
        return array;
    }

    uint256[50] private __gap;
}
