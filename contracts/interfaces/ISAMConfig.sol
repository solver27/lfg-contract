// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ISAMConfig {
    function getBurnAddress() external returns (address);
    function getRevenueAddress() external returns (address);
    function getFireNftAddress() external returns (address);
    function getRoyalityFeeRate() external returns (uint256);
}
