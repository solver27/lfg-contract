// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

uint256 constant FEE_RATE_BASE = 10000;

interface ISAMConfig {
    function getBurnAddress() external view returns (address);
    function getRevenueAddress() external view returns (address);
    function getFireNftAddress() external view returns (address);
    function getRoyalityFeeRate() external view returns (uint256);
    function getFeeBurnRate() external view returns (uint256);
    function getMinDuration() external view returns (uint256);
    function getMaxDuration() external view returns (uint256);
}
