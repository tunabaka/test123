// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "./extensions/ERC1155SupplyUpgradeable.sol";
import "./ERC1155Upgradeable.sol";
import "../../Oracle/v1/IOracle.sol";
import "../../Vote/v1/IVote.sol";
import "../../Token/v1/IToken.sol";
import "../../Staking/v1/IStaking.sol";

import "hardhat/console.sol";

contract Share is AccessControlEnumerableUpgradeable, ERC1155SupplyUpgradeable {

    uint256 constant PERCENTAGE_DP = 1e3; // percentage accuracy
    uint256 constant TH = 916331174;
    uint256 constant DP_POINTS_SHARES = 4;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    address public _addressOracle;
    address public _addressVote;
    address public _addressToken;
    address public _addressStaking;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    mapping(uint256 => uint256) private _coinsInToken;
    mapping(uint256 => uint256) private _coinsInTokenHistory;

    event Bought(
        address indexed account,
        uint256 tokenId,
        uint256 shares,
        uint256 amount,
        uint256 usdPrice,
        uint256 positive,
        uint256 negative,
        bool isPositive
    );

    event Sold(
        address indexed account,
        uint256 tokenId,
        uint256 shares,
        uint256 amount,
        uint256 usdPrice,
        uint256 positive,
        uint256 negative
    );

    function initialize() public initializer {
        __SharesUpgradeable_init();
    }

    function __SharesUpgradeable_init() internal onlyInitializing {
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __SharesUpgradeable_init_unchained();
    }

    function __SharesUpgradeable_init_unchained() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function isAdmin()
        private
        view
        returns (bool)
    {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender);
    }

    function adminAdd(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Share.adminAdd]: caller is not an owner");
        grantRole(ADMIN_ROLE, account);
    }

    function adminRemove(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Share.adminRemove]: caller is not an owner");
        revokeRole(ADMIN_ROLE, account);
    }

    function changeOracle(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Share.changeOracle]: must have admin role");
        _addressOracle = addressNew;
    }

    function changeVote(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Share.changeVote]: must have admin role");
        _addressVote = addressNew;
    }

    function changeToken(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Share.changeToken]: must have admin role");
        _addressToken = addressNew;
    }

    function changeStaking(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Share.changeStaking]: must have admin role");
        _addressStaking = addressNew;
    }

    function getRate(
        string memory pair
    )
        private
        view
        returns (IOracle.Value memory)
    {
        require(_addressOracle != address(0), "[Share.getRate]: oracle contract address must be set");
        IOracle oracle = IOracle(_addressOracle);
        IOracle.Value memory usdRate = oracle.getValue(pair, 0);
        return usdRate;
    }

    function sharesForValue(
        uint256 tokenId,
        uint256 value
    )
        public
        view
        returns (uint256)
    {
        require(value < 1e24, "[Share.sharesForValue]: maximum value is 1000000 coins");
        uint256 _totalSupply = totalSupply(tokenId);
        uint256 dp = 6;
        uint256 maxIters = 80;
        uint256 result = mainFormula(value /= 1e14, _totalSupply, dp, maxIters);
        return result;
    }

    function buySharesNewToken(
        uint256 tokenId,
        bool votePositive,
        address sender
    )
        public
        payable
    {
        _buySharesInternal(tokenId, votePositive, sender);
    }

    function buyShares(
        uint256 tokenId,
        bool votePositive
    )
        public
        payable
    {
        _buySharesInternal(tokenId, votePositive, msg.sender);
    }

    function _stakingAdd(
        address actor,
        uint256 tokenId,
        uint256 value,
        uint256 until
    ) private {
        if (_addressStaking == address(0)) return;
        IStaking staking = IStaking(_addressStaking);
        staking.add(actor, tokenId, value, until);
    }

    function _stakingWithdraw(
        address actor,
        uint256 tokenId,
        uint256 value
    ) private {
        if (_addressStaking == address(0)) return;
        IStaking staking = IStaking(_addressStaking);
        staking.withdraw(actor, tokenId, value);
    }

    function _buySharesInternal(
        uint256 tokenId,
        bool votePositive,
        address sender
    ) private {
        require(msg.value > 0, "[Share._buySharesInternal]: must put some value in index");
        require(msg.value < 1e24, "[Share._buySharesInternal]: maximum value is 1.000.000");
        // check other contracts addresses are set
        require(_addressVote != address(0), "[Share._buySharesInternal]: votes contract address must be set");

        // check token is validated & started
        IToken token = IToken(_addressToken);
        require(token.exists(tokenId), "[Share._buySharesInternal]: can not buy shares of burned tokens");

        bool isStarted = token.isStarted(tokenId);
        if (!isStarted) {
            address creatorOf = token.creatorOf(tokenId);
            require(isAdmin() || creatorOf == sender, "[Share._buySharesInternal]: can not buy shares before token start");
        }

        // how many index parts will participant get?
        uint256 shares = sharesForValue(tokenId, msg.value);
        require(shares > 0, "[Share._buySharesInternal]: no shares for this value");
        _mint(sender, tokenId, shares, '');

        // get USD rate at the moment of transaction
        IOracle.Value memory usdRate = getRate('USD');

        // add votes equal to transaction value
        IVote votes = IVote(_addressVote);
        votePositive
          ? votes.votePositive(sender, tokenId, msg.value)
          : votes.voteNegative(sender, tokenId, msg.value);
        IVote.Votes memory votesSummary = votes.getTotal(tokenId);

        // add staking for this deal
        _stakingAdd(sender, tokenId, msg.value, 0); // no until limit at this stage

        // increase this shares coins value
        _coinsInToken[tokenId] += msg.value;
        _coinsInTokenHistory[tokenId] += msg.value;
        emit Bought(sender, tokenId, shares, msg.value, usdRate.value, votesSummary.positive, votesSummary.negative, votePositive);
    }

    function votesTotal(
        uint256 tokenId
    )
        private
        view
        returns (IVote.Votes memory result)
    {
        require(_addressVote != address(0), "[Share.votesTotal]: votes contract address must be set");
        // remove votes equal to sell value percentage (with PERCENTAGE_DP accuracy)
        IVote votes = IVote(_addressVote);
        return votes.getTotal(tokenId);
    }

    function voteOut(
        address actor,
        uint256 tokenId,
        uint256 percentage
    )
        private
        returns (IVote.Votes memory result)
    {
        require(_addressVote != address(0), "[Share.voteOut]: votes contract address must be set");
        // remove votes equal to sell value percentage (with PERCENTAGE_DP accuracy)
        IVote votes = IVote(_addressVote);
        votes.voteOut(actor, tokenId, percentage);
        return votes.getTotal(tokenId);
    }

    function sellShares(
        uint256 tokenId,
        uint256 amount
    ) public {
        require(_addressOracle != address(0), "[Share.sellShares]: oracle contract address must be set");
        require(amount > 0, "[Share.sellShares]: amount should be greater 0");

        // check token is validated & started
        IToken token = IToken(_addressToken);

        if (token.exists(tokenId)) {
            bool isStarted = token.isStarted(tokenId);
            require(isStarted, "[Share.sellShares]: can not sell shares before token start");
        }

        uint256 balance = balanceOf(msg.sender, tokenId);
        require(balance > 0, "[Share.sellShares]: balance is zero");
        if (amount > balance) amount = balance;

        // how many coins should be sent to seller
        uint256 coinsToSend = 0;
        uint256 currentSupply = currentSupply(tokenId);
        uint256 sharePrice = 0;
        if (amount == currentSupply) {
            coinsToSend = _coinsInToken[tokenId];
        } else {
            sharePrice = sellPrice(tokenId);
           coinsToSend = amount * sharePrice;
        }

        // send coins to zero address (burn)
        safeTransferFrom(msg.sender, address(0), tokenId, amount, '');

        // decrease current coins value in this shares
        _coinsInToken[tokenId] -= coinsToSend;

        if (_coinsInToken[tokenId] == 0) {
            // reset token shares amount if no value in the token
            _resetTotalSupply(tokenId);
        }

        // get USD rate at the moment of transaction
        IOracle.Value memory usdRate = getRate('USD');
        uint256 votesToRemove = (amount * 100 * PERCENTAGE_DP) / balance;
        // Votes operations
        IVote.Votes memory votesPrev = votesTotal(tokenId);
        IVote.Votes memory votesNew = voteOut(msg.sender, tokenId, votesToRemove);
        uint256 coinsPrev = votesPrev.negative + votesPrev.positive;
        uint256 coinsNew = votesNew.negative + votesNew.positive;
        _stakingWithdraw(msg.sender, tokenId, coinsPrev - coinsNew);
        payable(msg.sender).transfer(coinsToSend);
        emit Sold(msg.sender, tokenId, amount, coinsToSend, usdRate.value, votesNew.positive, votesNew.negative);
    }

    function tokenCap(
        uint256 id
    )
        public
        view
        returns (uint256)
    {
        return _coinsInToken[id];
    }

    function coinsHistory(
        uint256 id
    )
        public
        view
        returns (uint256)
    {
        return _coinsInTokenHistory[id];
    }

    function sellPrice(
        uint256 id
    )
        public
        view
        returns (uint256)
    {
        uint256 _currentSupply = currentSupply(id);
        return _currentSupply == 0 ? 0 : _coinsInToken[id] / _currentSupply;
    }

    function sellPricePredict(
        uint256 tokenId,
        uint256 value
    )
        public
        view
        returns (uint256)
    {
        uint256 sharesFuture = sharesForValue(tokenId, value);
        uint256 coinsInIndexFuture = _coinsInToken[tokenId] + value;
        uint256 sharesSupplyFuture = currentSupply(tokenId) + sharesFuture;
        return sharesSupplyFuture == 0 ? 0 : coinsInIndexFuture / sharesSupplyFuture;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(AccessControlEnumerableUpgradeable, ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
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
        override(ERC1155SupplyUpgradeable)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function nthRoot(
        uint256 value,
        uint256 n,
        uint256 dp,
        uint256 maxIter
    )
        pure
        private
        returns(uint256)
    {
        uint256 x = 10 ** dp;
        uint256 valueNew = value * ((10 ** dp) ** n);
        uint256 count = 0;
        uint256 result;
        uint256 delta = valueNew < x ** n
          ?  x ** n - valueNew
          : valueNew - x ** n;
        while ((delta > 10 ** dp) && (count < maxIter)) {
            uint256 x1 = (n - 1) * x;
            uint256 x2 = x ** (n - 1);
            uint256 x3 = valueNew / x2;
            result = 10 ** (2 * dp) * (x1 + x3) / n;
            x = result / 10 ** (2 * dp);
            delta = valueNew < x ** n
              ?  x ** n - valueNew
              : valueNew - x ** n;
            count += 1;
        }
        return result;
    }

    function mainFormula(
        uint256 value1,
        uint256 value2,
        uint256 n,
        uint256 maxIter
    )
        pure
        private
        returns(uint256)
    {
        if (value1 == 0) return 0;
        uint256 root1 = ((nthRoot(value2, 4, n, maxIter) * nthRoot(10 ** 4, 4, n, maxIter))) / 10 ** 32;
        uint256 delta = 400;
        uint256 res1 = (625 * 10 ** 4 * value1 + value2 * root1) / 10 ** 4;
        uint256 res2 = res1 / 10 ** 4 ;
        uint256 root2 = nthRoot(res2, 5, n, maxIter) * 10 ** n;
        root2 = root2 / nthRoot(10 ** (n - 4), 5, n, maxIter);
        res1 = 10 ** 4 * res1 / root2;
        if (value2 > res1) return 0;
        uint256 result = res1 - value2;
        if (result < delta) return 0;
        return result - delta;
    }

    uint256[50] private __gap;
}
