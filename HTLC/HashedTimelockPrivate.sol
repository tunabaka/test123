// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

contract HashedTimelockPrivate {

    event LogHTLCNewPrivate(
        bytes32 indexed contractId,
        address indexed sender,
        address indexed receiver,
        uint256 amount,
        bytes32 hashlock,
        uint256 timelock
    );

    event LogHTLCWithdrawPrivate(bytes32 indexed contractId, string name);
    event LogHTLCRefundPrivate(bytes32 indexed contractId, string name);

    struct LockContract {
        address sender;
        address receiver;
        uint256 amount;
        bytes32 hashlock; // sha-2 sha256 hash
        uint256 timelock; // UNIX timestamp seconds - locked UNTIL this time
        bool withdrawn;
        bool refunded;
        bytes32 preimage;
        string name;
    }

    modifier fundsSent() {
        require(msg.value > 0, "[HashedTimelockPrivate.fundsSent] msg.value must be > 0");
        _;
    }

    modifier futureTimelock(
        uint256 time
    ) {
        // only requirement is the timelock time is after the last blocktime (now).
        // probably want something a bit further in the future then this.
        // but this is still a useful sanity check:
        require(time > block.timestamp, "[HashedTimelockPrivate.futureTimelock] time must be in the future");
        _;
    }

    modifier contractExists(
        bytes32 contractId
    ) {
        require(haveContract(contractId), "[HashedTimelockPrivate.contractExists] contractId does not exist");
        _;
    }

    modifier hashlockMatches(
        bytes32 contractId, bytes32 x
    ) {
        require(
            contracts[contractId].hashlock == sha256(abi.encodePacked(x)),
            "[HashedTimelockPrivate.hashlockMatches] hash does not match"
        );
        _;
    }

    modifier withdrawable(
        bytes32 contractId
    ) {
        require(contracts[contractId].receiver == msg.sender, "[HashedTimelockPrivate.withdrawable] not receiver");
        require(contracts[contractId].withdrawn == false, "[HashedTimelockPrivate.withdrawable] already withdrawn");
        require(contracts[contractId].timelock > block.timestamp, "[HashedTimelockPrivate.withdrawable] timelock time must be in the future");
        _;
    }

    modifier refundable(
        bytes32 contractId
    ) {
        require(contracts[contractId].sender == msg.sender, "[HashedTimelockPrivate.refundable] not sender");
        require(contracts[contractId].refunded == false, "[HashedTimelockPrivate.refundable] already refunded");
        require(contracts[contractId].withdrawn == false, "[HashedTimelockPrivate.refundable] already withdrawn");
        require(contracts[contractId].timelock <= block.timestamp, "[HashedTimelockPrivate.refundable] timelock not yet passed");
        _;
    }

    mapping (bytes32 => LockContract) contracts;

    function newContract(
        address payable receiver,
        bytes32 hashlock,
        uint256 timelock,
        string memory name
    )
        external
        payable
        fundsSent
        futureTimelock(timelock)
        returns (bytes32 contractId)
    {
        contractId = hashlock;
        // Reject if a contract already exists with the same parameters. The
        // sender must change one of these parameters to create a new distinct contract.
        if (haveContract(contractId)) revert("[HashedTimelockPrivate.newContract] contract already exists");
        contracts[contractId] = LockContract(
            msg.sender,
            receiver,
            msg.value,
            hashlock,
            timelock,
            false,
            false,
            0x0,
            name
        );
        emit LogHTLCNewPrivate(
            contractId,
            msg.sender,
            receiver,
            msg.value,
            hashlock,
            timelock
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
        emit LogHTLCWithdrawPrivate(contractId, c.name);
        return true;
    }

    function refund(
        bytes32 contractId
    )
        external
        contractExists(contractId)
        refundable(contractId)
        returns (bool)
    {
        LockContract storage c = contracts[contractId];
        c.refunded = true;
        payable(c.sender).transfer(c.amount);
        emit LogHTLCRefundPrivate(contractId, c.name);
        return true;
    }

    function getContract(
        bytes32 contractId
    )
        public
        view
        returns (
            address sender,
            address receiver,
            uint256 amount,
            bytes32 hashlock,
            uint256 timelock,
            bool withdrawn,
            bool refunded,
            bytes32 preimage,
            string memory name
        )
    {
        if (haveContract(contractId) == false) return (address(0), address(0), 0, 0, 0, false, false, 0, '');
        LockContract storage c = contracts[contractId];
        return (
            c.sender,
            c.receiver,
            c.amount,
            c.hashlock,
            c.timelock,
            c.withdrawn,
            c.refunded,
            c.preimage,
            name
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
