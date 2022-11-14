// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import "hardhat/console.sol";

contract Oracle is Initializable, AccessControlEnumerableUpgradeable {

    event ValueChanged(uint256 indexed time, string indexed symbol, uint256 value);

    struct Value {
        uint256 time;
        uint256 value;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(string => Value[]) private _values;
    uint256 private DP;
    address public _addressSaleWallet;
    address public _addressShare;

    function initialize() public initializer {
        __Oracle_init();
    }

    function __Oracle_init() internal onlyInitializing {
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __Oracle_init_unchained();
    }

    function __Oracle_init_unchained() internal onlyInitializing {
        DP = 1e8;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function adminAdd(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Oracle.adminAdd]: must have admin role");
        grantRole(ADMIN_ROLE, account);
    }

    function adminRemove(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Oracle.adminRemove]: must have admin role");
        revokeRole(ADMIN_ROLE, account);
    }

    function changeShare(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Oracle.changeShare]: must have admin role");
        _addressShare = addressNew;
    }

    function changePublicSaleWallet(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Oracle.changePublicSaleWallet]: must have admin role");
        _addressSaleWallet = addressNew;
    }

    function getValue(
        string memory symbol,
        uint256 time
    )
        public
        view
        returns (Value memory)
    {
        Value memory zeroValue = Value({ time: 0, value: 0 });
        if (_values[symbol].length == 0) return zeroValue;
        if (time == 0) return _values[symbol][_values[symbol].length - 1];
        for (uint256 i = _values[symbol].length; i > 0; i--) {
            if (_values[symbol][i - 1].time < time) return _values[symbol][i - 1];
        }
        return zeroValue;
    }

    function setValue(
        string memory symbol,
        uint256 value
    ) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Oracle: caller is not an owner");
        _values[symbol].push(Value({
            time: block.timestamp,
            value: value
        }));
        emit ValueChanged(block.timestamp, symbol, value);
    }

    function _coinRateMinRate() view private returns (uint256) {
        // coin minimum rate
        string memory coinRateMinName = 'COIN_RATE_MIN';
        require(_values[coinRateMinName].length != 0, "[Oracle._coinRateMinRate]: coin min rate must be set");
        uint256 result = _values[coinRateMinName][_values[coinRateMinName].length - 1].value;
        require(result != 0, "[Oracle._coinRateMinRate]: coin min rate must be more than zero");
        return result;
    }

    function _coinRateMaxRate() view private returns (uint256) {
        // coin maximum rate for period
        string memory coinRateMaxName = 'COIN_RATE_MAX';
        require(_values[coinRateMaxName].length != 0, "[Oracle._coinRateMaxRate]: coin max rate must be set");
        uint256 result = _values[coinRateMaxName][_values[coinRateMaxName].length - 1].value;
        require(result != 0, "[Oracle._coinRateMaxRate]: coin max rate must be more than zero");
        return result;
    }

    function _coinRatePubSaleAmount() view private returns (uint256) {
        // initial public sale wallet balance
        string memory pubSaleAmountName = 'PUB_SALE_AMOUNT';
        require(_values[pubSaleAmountName].length != 0, "[Oracle._coinRatePubSaleAmount]: public sale initial amount must be set");
        uint256 result = _values[pubSaleAmountName][_values[pubSaleAmountName].length - 1].value;
        require(result >= 1e6 * 1e18, "[Oracle._coinRatePubSaleAmount]: public sale initial amount must be more than 1000000");
        return result;
    }

    function _coinRatePubSaleSoldAmount(uint256 sellAmount) view private returns (uint256) {
        // already sold coins amount
        require(_addressSaleWallet != address(0), "[Oracle._coinRatePubSaleSoldAmount]: public sale wallet address must be set");
        uint256 balanceSellWallet = address(_addressSaleWallet).balance;
        uint256 result = sellAmount - balanceSellWallet;
        return (result > sellAmount) ? sellAmount : result;
    }

    function _coinRateLockedAmount() view private returns (uint256) {
        // coins locked in tokens
        require(_addressShare != address(0), "[Oracle._coinRateLockedAmount]: shares contract address must be set");
        return address(_addressShare).balance;
    }

    function _coinRateGrowStart() view private returns (uint256) {
        // when coin rate will start growing
        string memory growStartName = 'COIN_RATE_GROW_START';
        require(_values[growStartName].length != 0, "[Oracle._coinRateGrowStart]: grow start time must be set");
        uint256 result = _values[growStartName][_values[growStartName].length - 1].value;
        require(result >= 1664530000, "[Oracle._coinRateGrowStart]: grow start time too low");
        return result;
    }

    function _coinRateGrowStop() view private returns (uint256) {
        // when coin rate will start growing
        string memory growStopName = 'COIN_RATE_GROW_STOP';
        require(_values[growStopName].length != 0, "[Oracle._coinRateGrowStop]: grow stop time must be set");
        uint256 result = _values[growStopName][_values[growStopName].length - 1].value;
        require(result >= 1664530000, "[Oracle._coinRateGrowStop]: grow stop time too low");
        return result;
    }

    function coinRate() view public returns (uint256) {
        uint256 tempDP = 1e8;
        uint256 rateMin = _coinRateMinRate();
        uint256 rateMax = _coinRateMaxRate();
        require(rateMin <= rateMax, "[Oracle.coinRate]: minimum rate should be not less than maximum rate");
        uint256 sellAmount = _coinRatePubSaleAmount();
        uint256 soldAmount = _coinRatePubSaleSoldAmount(sellAmount);
        uint256 lockedAmount = _coinRateLockedAmount();
        uint256 rateGrowStart = _coinRateGrowStart();
        uint256 rateGrowStop = _coinRateGrowStop();
        uint256 timestamp = block.timestamp;

        require(rateGrowStart <= rateGrowStop, "[Oracle.coinRate]: grow start time must be less then stop time");
        if (rateMin == rateMax || rateGrowStart == rateGrowStop) return rateMax;
        if (timestamp < rateGrowStart) return rateMin;

        uint256 influenceParam = (rateMax - rateMin) / 3;
//        console.logString('influenceParam');
//        console.logUint(influenceParam);

        // time influence
        uint256 timeInfluence = influenceParam * ((timestamp - rateGrowStart) * 100 * tempDP) / (rateGrowStop - rateGrowStart) / (100 * tempDP);
//        console.logString('timeInfluence');
//        console.logUint(timeInfluence);

        // total sold influence
        uint256 soldInfluence = influenceParam * ((soldAmount * 100 * tempDP) / sellAmount) / (100 * tempDP);
//        console.logString('soldInfluence');
//        console.logUint(soldInfluence);

        // sold locked in tokens influence
        uint256 lockedInfluence = influenceParam * ((lockedAmount * 100 * tempDP) / sellAmount) / (100 * tempDP);
//        console.logString('lockedInfluence');
//        console.logUint(lockedInfluence);
        uint256 summAdd = timeInfluence + soldInfluence + lockedInfluence;
//        console.logString('summAdd');
//        console.logUint(summAdd);
        return rateMin + summAdd;
    }

    uint256[50] private __gap;
}
