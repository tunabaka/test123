// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./IERC721Upgradeable.sol";

interface IERC721MetadataUpgradeable is IERC721Upgradeable {

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(address tokenId) external view returns (string memory);

}
