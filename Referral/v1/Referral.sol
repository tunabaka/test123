// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract ReferralUpgradeable_1 is Initializable, AccessControlEnumerableUpgradeable {

    event ReferralPayment(
        address indexed referrer,
        address indexed referral,
        bytes32 reason,
        uint8 level,
        uint256 value
    );

    struct Payment {
        address referral;
        bytes32 reason;
        uint8 level;
        uint256 time;
        uint256 value;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(address => address[]) private _referrers;
    mapping(address => address[]) private _referrals;
    mapping(address => Payment[]) private _payments;
    mapping(address => uint256) private _paymentsSummary;

    function initialize() public initializer {
        __ReferralUpgradeable_init_unchained();
    }

    function __ReferralUpgradeable_init_unchained() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function adminAdd(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Referral: caller is not an owner");
        grantRole(ADMIN_ROLE, account);
    }

    function adminRemove(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Referral: caller is not an owner");
        revokeRole(ADMIN_ROLE, account);
    }

    function referredBy(
        address referrer
    )
        public
        view
        returns (address[] memory)
    {
        return _referrers[referrer];
    }

    function referrals(
        address referrer
    )
        public
        view
        returns (address[] memory)
    {
        return _referrals[referrer];
    }

    function addReferral(
        address referrer,
        address referral
    ) public {
        require(_referrers[referral].length == 0, "Referral: User is already registered");
        for (uint256 i = 0; i < _referrers[referrer].length; ++i) {
            _referrers[referral].push(_referrers[referrer][i]);
        }
        _referrers[referral].push(referrer);
        _referrals[referrer].push(referral);
    }

    function addPayment(
        address referrer,
        address referral,
        bytes32 reason,
        uint8 level,
        uint256 value
    ) public {
        require(referrer != address(0) && referral != address(0), "Referral: referral and referrer must be specified");
        require(hasRole(ADMIN_ROLE, msg.sender), "Referral: caller is not an administrator");
        _payments[referrer].push(Payment({
            referral: referral,
            reason: reason,
            level: level,
            time: block.timestamp,
            value: value
        }));
        _paymentsSummary[referrer] += value;
        emit ReferralPayment(referrer, referral, reason, level, value);
    }

    function refSummary(
        address referrer
    )
        public
        view
        returns (uint256 totalPayments, uint256 totalValue)
    {
        return (_paymentsSummary[referrer], _payments[referrer].length);
    }

    function refHistory(
        address referrer,
        uint256 indexFrom,
        uint256 indexTo
    )
        public
        view
        returns (Payment[] memory payments)
    {
        if (indexTo >= _payments[referrer].length) indexTo = _payments[referrer].length;
        if (indexFrom > indexTo) indexFrom = indexTo;
        Payment[] memory results = new Payment[](indexTo - indexFrom);
        uint256 counter = 0;
        for (uint256 i = indexFrom; i < indexTo; i++) {
            Payment storage payment = _payments[referrer][i];
            payments[counter++] = payment;
        }
        return results;
    }

    uint256[50] private __gap;
}
