// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

contract HashedTimelock {

    event LogHTLCNew(
        address indexed sender,
        address indexed receiver,
        address recipient,
        bytes32 hashlock,
        uint256 timelock,
        uint256 amount
    );

    event LogHTLCWithdraw(bytes32 indexed contractId);
    event LogHTLCRefund(bytes32 indexed contractId, bool timeless);

    struct LockContract {
        address sender;
        address receiver;
        address recipient;
        uint256 amount;
        bytes32 hashlock; // sha-2 sha256 hash
        uint256 timelock; // UNIX timestamp seconds - locked UNTIL this time
        bool withdrawn;
        bool refunded;
        bytes32 preimage;
    }

    modifier fundsSent() {
        require(msg.value > 0, "[HashedTimelock.fundsSent] msg.value must be > 0");
        _;
    }

    modifier futureTimelock(
        uint256 time
    ) {
        require(time > block.timestamp, "[HashedTimelock.futureTimelock] time must be in the future");
        _;
    }

    modifier contractExists(
        bytes32 contractId
    ) {
        require(haveContract(contractId), "[HashedTimelock.contractExists] contractId does not exist");
        _;
    }

    modifier hashlockMatches(
        bytes32 contractId,
        bytes32 x
    ) {
        require(contracts[contractId].hashlock == sha256(abi.encodePacked(x)), "[HashedTimelock.hashlockMatches] hash does not match");
        _;
    }

    modifier withdrawable(
        bytes32 contractId
    ) {
        require(contracts[contractId].receiver == msg.sender, "[HashedTimelock.withdrawable] not receiver");
        require(contracts[contractId].withdrawn == false, "[HashedTimelock.withdrawable] already withdrawn");
        require(contracts[contractId].timelock > block.timestamp, "[HashedTimelock.withdrawable] timelock time must be in the future");
        _;
    }

    mapping (bytes32 => LockContract) contracts;

    function newContract(
        address payable receiver,
        address recipient,
        bytes32 hashlock,
        uint256 timelock
    )
        external
        payable
        fundsSent
        futureTimelock(timelock)
    {
        require(!haveContract(hashlock), "[HashedTimelock.newContract] contract already exists");
        contracts[hashlock] = LockContract(
            msg.sender,
            receiver,
            recipient,
            msg.value,
            hashlock,
            timelock,
            false,
            false,
            0x0
        );
        emit LogHTLCNew(
            msg.sender,
            receiver,
            recipient,
            hashlock,
            timelock,
            msg.value
        );
    }

    function withdraw(
        bytes32 contractId,
        bytes32 preimage
    )
        external
        contractExists(contractId)
        hashlockMatches(contractId, preimage)
        withdrawable(contractId)
        returns (bool)
    {
        LockContract storage c = contracts[contractId];
        c.preimage = preimage;
        c.withdrawn = true;
        payable(c.receiver).transfer(c.amount);
        emit LogHTLCWithdraw(contractId);
        return true;
    }

    function refund(
        bytes32 contractId
    )
        public
        contractExists(contractId)
    {
        LockContract storage c = contracts[contractId];
        require(c.sender == msg.sender, "[HashedTimelock.refund] not sender");
        require(c.refunded == false, "[HashedTimelock.refund] already refunded");
        require(c.withdrawn == false, "[HashedTimelock.refund] already withdrawn");
        require(c.timelock <= block.timestamp, "[HashedTimelock.refund] timelock not yet passed");
        c.refunded = true;
        payable(c.sender).transfer(c.amount);
        emit LogHTLCRefund(contractId, uint256(c.timelock) > uint256(block.timestamp));
    }

    function getContract(
        bytes32 contractId
    )
        public
        view
        returns
    (
        address sender,
        address receiver,
        address recipient,
        uint256 amount,
        bytes32 hashlock,
        uint256 timelock,
        bool withdrawn,
        bool refunded,
        bytes32 preimage
    ) {
        if (haveContract(contractId) == false) return (address(0), address(0), address(0), 0, 0, 0, false, false, 0);
        LockContract storage c = contracts[contractId];
        return (
            c.sender,
            c.receiver,
            c.recipient,
            c.amount,
            c.hashlock,
            c.timelock,
            c.withdrawn,
            c.refunded,
            c.preimage
        );
    }

    function haveContract(
        bytes32 contractId
    )
        internal
        view
        returns (bool exists)
    {
        exists = (contracts[contractId].sender != address(0));
    }
}
