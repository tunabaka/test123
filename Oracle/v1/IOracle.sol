// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

interface IOracle {

    struct Value {
        uint256 time;
        uint256 value;
    }

    function getValue(string memory symbol, uint256 time) external view returns (Value memory);

}
