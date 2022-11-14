// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "../../Oracle/v1/IOracle.sol";

contract Staking is Initializable, AccessControlEnumerableUpgradeable {

    event StakingStarted(address indexed actor, uint256 tokenId, uint256 value, uint256 apr, uint256 started, uint256 until);
    event Received(address, uint256);
    event StakePayment(address indexed actor, uint256 tokenId, uint256 stake);

    struct StakingItem {
        uint256 tokenId;
        uint256 value;
        uint256 apr;
        uint256 started;
        uint256 until;
    }

    struct StakingStateItem {
        uint256 value;
        uint256 stake;
        uint256 apr;
        uint256 started;
        uint256 until;
    }

    uint256 private DP;
    address public _addressOracle;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant STARTER_ROLE = keccak256("STARTER_ROLE");
    mapping(address => mapping(uint256 => StakingItem[])) private _stakings;
    mapping(address => uint256[]) private _userTokenIds;

    function initialize() public virtual initializer {
        __Staking_init();
    }

    function __Staking_init() internal onlyInitializing {
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __Staking_init_unchained();
    }

    function __Staking_init_unchained() internal onlyInitializing {
        DP = 1e10;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function adminAdd(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Staking.adminAdd]: must have admin role");
        grantRole(ADMIN_ROLE, account);
    }

    function adminRemove(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Staking.adminRemove]: must have admin role");
        revokeRole(ADMIN_ROLE, account);
    }

    function changeOracle(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Staking.changeOracle]: must have admin role");
        _addressOracle = addressNew;
    }

    function starterAdd(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Staking.starterAdd]: must have admin role");
        grantRole(STARTER_ROLE, account);
    }

    function starterRemove(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Staking.starterRemove]: must have admin role");
        revokeRole(STARTER_ROLE, account);
    }

    function currentAPR()
        public
        view
        returns (uint256)
    {
        if (_addressOracle == address(0)) return 0;
        IOracle oracleRates = IOracle(_addressOracle);
        uint256 stakingMaxPerc = oracleRates.getValue("ST_MAX", 0).value;
        uint256 stakingMinPerc = oracleRates.getValue("ST_MIN", 0).value;
        uint256 stakingStarted = oracleRates.getValue("ST_START", 0).value;
        uint256 stakingStable = oracleRates.getValue("ST_STABLE", 0).value;
        uint256 timestamp = block.timestamp;
        if (
            stakingMaxPerc == 0 // max apr not set
            || stakingMaxPerc < stakingMinPerc // wrong parameters
            || stakingStarted > stakingStable // wrong parameters
            || stakingStarted == 0 // staking is blocked
            || stakingStarted > timestamp // staking timestamp is not became yet
        ) return 0;
        if (stakingStable <= timestamp) return stakingMinPerc * DP; // stable time is already in past, using min value
        uint256 timePerc = ((timestamp - stakingStarted) * 100 * DP) / (stakingStable - stakingStarted);
        uint256 addPerc = (stakingMaxPerc - stakingMinPerc) * timePerc / 100;
        uint256 result = stakingMinPerc * DP + ((stakingMaxPerc - stakingMinPerc) * DP - addPerc);
        return result;
    }

    function add(
        address actor,
        uint256 tokenId,
        uint256 value,
        uint256 until
    ) public {
        require(hasRole(STARTER_ROLE, msg.sender), "[Staking.add]: must have starter role");
        require(_stakings[actor][tokenId].length < 100, "[Staking.add]: maximum stakes per token is 100");
        uint256 apr = currentAPR();
        if (apr == 0) return;
        uint256 timestamp = block.timestamp;
        uint256 tokenIndex = _userTokenIndex(actor, tokenId);
        if (tokenIndex == _userTokenIds[actor].length) {
            _userTokenIds[actor].push(tokenId); // new token for user
        }
        _stakings[actor][tokenId].push(StakingItem({
            tokenId: tokenId,
            value: value,
            apr: apr,
            started: timestamp,
            until: until
        }));
        emit StakingStarted(actor, tokenId, value, apr, timestamp, until);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function withdraw(
        address actor,
        uint256 tokenId,
        uint256 value
    ) public {
        require(hasRole(STARTER_ROLE, msg.sender), "[Staking.withdraw]: must have starter role");
        uint256 itemsCount = _stakings[actor][tokenId].length;
        if (itemsCount == 0) return;
        uint256 valueLeft = value;
        uint256 totalPayment = 0;
        for (uint256 i = itemsCount - 1; i >= 0; i--) {
            uint256 valueForStake = min(valueLeft, _stakings[actor][tokenId][i].value);
            if (valueForStake <= 0) break;
            uint256 stake = _stake(
                valueForStake,
                _stakings[actor][tokenId][i].apr,
                _stakings[actor][tokenId][i].started
            );
            totalPayment += stake;
            if (_stakings[actor][tokenId][i].value <= valueLeft) {
                // should remove last stake
                valueLeft -= min(valueLeft, _stakings[actor][tokenId][i].value);
                _stakings[actor][tokenId].pop();
                if (_stakings[actor][tokenId].length == 0) {
                    break;
                }
            } else {
                // should sub value from last stake
                _stakings[actor][tokenId][i].value -= valueLeft;
                break;
            }
        }
        if (
            _stakings[actor][tokenId].length > 0
            && _stakings[actor][tokenId][_stakings[actor][tokenId].length - 1].value <= DP
        ) {
            // round down to DP
            _stakings[actor][tokenId].pop();
        }
        if (
            _stakings[actor][tokenId].length == 0
        ) {
            delete _stakings[actor][tokenId];
            uint256 tokenIndex = _userTokenIndex(actor, tokenId);
            if (tokenIndex < _userTokenIds[actor].length) {
                // no more stakes with this token id
                _removeUserTokenId(actor, tokenIndex);
            }
        }
        uint256 balance = address(this).balance;
        require(balance >= totalPayment, "[Staking.withdraw]: contract balance is too low");
        payable(actor).transfer(totalPayment);
        emit StakePayment(actor, tokenId, totalPayment);
    }

    function _stake(
        uint256 value,
        uint256 apr,
        uint256 started
    )
        internal
        view
        returns (uint256)
    {
        uint256 timestamp = block.timestamp;
        uint256 yearTime = 365 * 24 * 60 * 60;
        uint256 aprTime = started + yearTime;
        if (timestamp - started == 0) return 0;
        uint256 timePerc = (timestamp - started) * 100 * DP / (aprTime - started);
        uint256 stakePerc = apr * timePerc / (100 * (DP ^ 2));
        uint256 stake = value * stakePerc / (100 * (DP ^ 2));
        return stake;
    }

    function stakesByTokenId(
        address actor,
        uint256 tokenId
    )
        public
        view
        returns (StakingStateItem[] memory stakes)
    {
        uint256 itemsCount = _stakings[actor][tokenId].length;
        StakingStateItem[] memory results = new StakingStateItem[](itemsCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < itemsCount; i++) {
            StakingStateItem memory item = StakingStateItem({
                value: _stakings[actor][tokenId][i].value,
                apr: _stakings[actor][tokenId][i].apr,
                started: _stakings[actor][tokenId][i].started,
                until: _stakings[actor][tokenId][i].until,
                stake: _stake(
                    _stakings[actor][tokenId][i].value,
                    _stakings[actor][tokenId][i].apr,
                    _stakings[actor][tokenId][i].started
                )
            });
            results[counter++] = item;
        }
        return results;
    }

    function _userTokenIndex(
        address actor,
        uint256 tokenId
    )
        internal
        view
        returns (uint256)
    {
        uint256 index = _userTokenIds[actor].length;
        for (uint256 i = 0; i < _userTokenIds[actor].length; i++) {
            if(_userTokenIds[actor][i] != tokenId) continue;
            index = i;
            break;
        }
        return index;
    }

    function userStakedTokens(
        address actor
    )
        public
        view
        returns (uint256[] memory)
    {
        return _userTokenIds[actor];
    }

    function _removeUserTokenId(
        address actor,
        uint256 index
    ) internal {
        require(index < _userTokenIds[actor].length, "[Staking._removeItem]: wrong item index");
        for (uint256 i = index; i < _userTokenIds[actor].length - 1; i++) {
            _userTokenIds[actor][i] = _userTokenIds[actor][i + 1];
        }
        _userTokenIds[actor].pop();
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    uint256[50] private __gap;
}
