// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceSource {
    function latestAnswer() external view returns (int256);
    function latestRound() external view returns (uint256);
}