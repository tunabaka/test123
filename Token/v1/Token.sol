// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./extensions/ERC721ValidatedUpgradable.sol";
import "./extensions/ERC721URIStorageUpgradeable.sol";
import "./extensions/ERC721TaggableUpgradable.sol";
import "./extensions/ERC721QueueUpgradable.sol";
import "../../Oracle/v1/IOracle.sol";
import "../../Share/v1/IShare.sol";

contract Token is
Initializable,
AccessControlEnumerableUpgradeable,
ERC721URIStorageUpgradeable,
TaggableUpgradable,
ERC721ValidatedUpgradable,
ERC721PausableUpgradeable,
ERC721QueueUpgradable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    CountersUpgradeable.Counter private _tokenIdTracker;
    string private _baseTokenURI;
    address _addressShare;
    address _addressOracle;

    struct TokenItem {
        uint256 tokenId;
        string tokenURI;
        uint256 createdAt;
        uint256 startTime;
        address creator;
        string symbol;
    }

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _creators;

    // Mapping from token ID to started timestamp
    mapping(uint256 => uint256) private _createdAt;

    // Mapping from token symbol to token id
    mapping(string => uint256) private _tokenIdBySymbol;

    // Mapping from token id to symbol
    mapping(uint256 => string) private _tokenSymbolById;

    //    event TokenCreated(address indexed owner, uint256 indexed tokenId, string indexed symbol);

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) public initializer {
        __ERC721Token_init(name, symbol, baseTokenURI);
    }

    function __ERC721Token_init(
        string memory name,
        string memory symbol,
        string memory baseTokenURI
    ) internal onlyInitializing {
        __ERC165_init_unchained();
        __ERC721_init_unchained(name, symbol);
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();
        __Pausable_init_unchained();
        __ERC721Pausable_init_unchained();
        __ERC721URIStorage_init_unchained();
        __ERC721Validated_unchained();
        __ERC721Queue_unchained();
        __ERC721Token_init_unchained(baseTokenURI);
    }

    function __ERC721Token_init_unchained(
        string memory baseTokenURI
    ) internal onlyInitializing {
        _baseTokenURI = baseTokenURI;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(VALIDATOR_ROLE, msg.sender);
    }

    function isAdmin() public view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender);
    }

    function adminAdd(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Token.adminAdd]: must have admin role");
        grantRole(ADMIN_ROLE, account);
    }

    function adminRemove(
        address account
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Token.adminRemove]: must have admin role");
        revokeRole(ADMIN_ROLE, account);
    }

    function changeOracle(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Token.changeOracle]: must have admin role");
        _addressOracle = addressNew;
    }

    function changeShare(
        address addressNew
    ) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "[Token.changeShare]: must have admin role");
        _addressShare = addressNew;
    }

    function baseURI()
        public
        view
        returns (string memory)
    {
        return _baseTokenURI;
    }

    function _baseURI()
        internal
        view
        override
        returns (string memory)
    {
        return _baseTokenURI;
    }

    function getMinInitialValue ()
        private
        view
        returns (IOracle.Value memory)
    {
        IOracle oracle = IOracle(_addressOracle);
        IOracle.Value memory result = oracle.getValue('TMIV', 0); // TMIV = Token Minimum initial Value
        return result;
    }

    function exists(
        uint256 tokenId
    )
        public
        view
        returns (bool)
    {
        return _exists(tokenId);
    }

    function tokenIdBySymbol(
        string memory symbol
    )
        public
        view
        returns (int256)
    {
        return _tokenIdBySymbol[symbol] == 0 ? -1 : int256(_tokenIdBySymbol[symbol] - 1);
    }

    function tokenSymbolById(
        uint256 tokenId
    )
        public
        view
        returns (string memory symbol)
    {
        return _tokenSymbolById[tokenId];
    }

    function totalSupply()
        public
        view
        returns (uint256)
    {
        return _tokenIdTracker.current();
    }

    function mint(
        string memory tokenURI,
        string memory symbol,
        string[] memory tags,
        bool votePositive
    )
        public
        payable
    {
        // check shares contract address is set
        require(_addressShare != address(0), "[Token.mint]: shares contract address must be set");

        // check token symbol
        bytes memory symbolBytes = bytes(symbol);
        require(symbolBytes.length > 0, "[Token.mint]: token symbol is required");
        require(isLowerCaseString(symbol), "[Token.mint]: only digits and lowercase [a-z] are allowed");
        require(_tokenIdBySymbol[symbol] <= 0, "[Token.mint]: token symbol is busy");

        // check minimum value to start token
        require(msg.value >= getMinInitialValue().value * 1e18, "[Token.mint]: must put minimum value in token");

        // check token has unique uri
        require(!tokenURIExists(tokenURI), "[Token.mint]: duplicate token URI");

        // check token has at least 1 tag
        require(tags.length > 0, "[Token.mint]: token tag required");

        // check token has only allowed tags
        for (uint256 i = 0; i < tags.length; i++) {
            require(_tagExists(tags[i]), "[Token.mint]: tag not exists");
        }
        uint256 current = _tokenIdTracker.current();

        // set token unvalidated
        _unvalidate(current, symbol);

        // link token symbol with tokenId
        _tokenIdBySymbol[symbol] = current + 1;
        _tokenSymbolById[current] = symbol;

        _mint(_addressShare, current);
        _setTokenURI(current, tokenURI, true);

        // save token creator for shares contract checks
        _creators[current] = msg.sender;

        // save token creation timestamp
        _createdAt[current] = block.timestamp;

        // buy initial shares for new token
        IShare share = IShare(_addressShare);
        share.buySharesNewToken{value: msg.value}(current, votePositive, msg.sender);
        //        emit TokenCreated(_addressShare, current, symbol);
        _tokenIdTracker.increment();
    }

    function getTokens(
        uint256 indexFrom,
        uint256 itemsCount
    )
        public
        view
        returns (TokenItem[] memory tokens)
    {
        uint256 totalTokens = totalSupply();
        if (indexFrom > totalTokens) indexFrom = totalTokens;
        if (indexFrom + itemsCount > totalTokens) itemsCount = totalTokens - indexFrom;
        if (itemsCount < 0) itemsCount = 0;
        TokenItem[] memory results = new TokenItem[](itemsCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < itemsCount; i++) {
            uint256 index = indexFrom + i;
            TokenItem memory token = TokenItem({
                tokenId: index,
                creator: _creators[index],
                createdAt: _createdAt[index],
                tokenURI: tokenURIById(index),
                symbol: _tokenSymbolById[index],
                startTime: _startedAt[index]
            });
            if (_isQueued(index)) {
                token.startTime = _queuedItemByTokenId(index).startTime;
            } else if (!_isValidated(index)) {
                token.startTime = MAX_INT;
            }
            results[counter++] = token;
        }
        return results;
    }

    function burn(
        uint256 tokenId
    ) public {
        require(isAdmin() || hasRole(VALIDATOR_ROLE, msg.sender), "[Token.burn]: must have validator or admin role");
        _burnNFT(tokenId);
        delete _creators[tokenId];
        string memory symbol = _tokenSymbolById[tokenId];
        // free token symbol
        delete _tokenIdBySymbol[symbol];
        delete _tokenSymbolById[tokenId];
        // remove token from unvalidated
        if (!_isValidated(tokenId)) _removeUnvalidated(tokenId);
        // remove token from starting queue
        if (_isQueued(tokenId)) _removeFromQueue(tokenId, false);
    }

    function setTokenURI(
        uint256 tokenId,
        string memory tokenURI
    ) public {
        if (isStarted(tokenId)) {
            require(isAdmin(), "[Token.setTokenURI]: must have admin role");
        } else {
            require(isAdmin() || hasRole(VALIDATOR_ROLE, msg.sender), "[Token.setTokenURI]: must have validator or admin role");
        }
        _setTokenURI(tokenId, tokenURI, false);
    }

    function pause() public {
        require(isAdmin(), "[Token.pause]: must have admin role");
        _pause();
    }

    function unpause() public {
        require(isAdmin(), "[Token.unpause]: must have admin role");
        _unpause();
    }

    function tagAdd(
        string memory tag
    ) public {
        require(isAdmin(), "[Token.tagAdd]: must have admin role");
        _tagAdd(tag);
    }

    function tagRemove(
        string memory tag
    ) public {
        require(isAdmin(), "[Token.tagRemove]: must have admin role");
        _tagRemove(tag);
    }

    function validatorAdd(
        address account
    ) public {
        require(isAdmin(), "[Token.validatorAdd]: must have admin role");
        grantRole(VALIDATOR_ROLE, account);
    }

    function validatorRemove(
        address account
    ) public {
        require(isAdmin(), "[Token.validatorRemove]: must have admin role");
        revokeRole(VALIDATOR_ROLE, account);
    }

    function isValidator(
        address account
    )
        public
        view
        returns (bool)
    {
        return hasRole(VALIDATOR_ROLE, account);
    }

    function unvalidatedCount()
        public
        view
        returns (uint256)
    {
        return  _getUnvalidatedCount();
    }

    function unvalidated(
        uint256 index
    )
        public
        view
        returns (uint256)
    {
        return  _getUnvalidated(index);
    }

    function getUnvalidatedIds()
        public
        view
        returns (uint256[] memory tokenIds)
    {
        return  _getUnvalidatedIds();
    }

    function validate(
        uint256 tokenId,
        uint256 startTime
    ) public {
        require(isAdmin() || hasRole(VALIDATOR_ROLE, msg.sender), "[Token.validate]: must have validator or admin role");
        _validate(tokenId);
        _queueAdd(tokenId, startTime);
    }

    function isValidated(
        uint256 tokenId
    )
        public
        view
        returns (bool)
    {
        return _isValidated(tokenId);
    }

    function getQueueLength()
        public
        view
        returns (uint256)
    {
        return  _getQueueLength();
    }

    function getQueue()
        public
        view
        returns (QueueItem[] memory tokens)
    {
        return _queueGet();
    }

    function creatorOf(
        uint256 tokenId
    )
        public
        view
        returns (address)
    {
        return _creators[tokenId];
    }

    function isQueued(
        uint256 tokenId
    )
        public
        view
        returns (bool)
    {
        return  _isQueued(tokenId);
    }

    function isStarted(
        uint256 tokenId
    )
        public
        view
        returns (bool)
    {
        return _creators[tokenId] != address(0) && _isValidated(tokenId) && !_isQueued(tokenId);
    }

    function startTokens(
        uint256[] memory tokenIds
    ) public {
        require(isAdmin(), "[Token.startTokens]: must have admin role");
        return _startTokens(tokenIds);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    )
        internal
        override(ERC721Upgradeable, ERC721PausableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(AccessControlEnumerableUpgradeable, ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function isLowerCaseString(
        string memory str
    )
        internal
        pure
        returns (bool)
    {
        bytes memory bStr = bytes(str);
        for (uint256 i = 0; i < bStr.length; i++) {
            uint8 uval = uint8(bStr[i]);
            if (
                !(uval >= 97 && uval <= 122)
                && !(uval >= 48 && uval <= 57)
            ) return false;
        }
        return true;
    }

    uint256[50] private __gap;
}
