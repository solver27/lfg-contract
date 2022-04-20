// SPDX-License-Identifier: MIT

//** NFT Airdrop Contract */
//** Author Xiao Shengguang : NFT Airdrop Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISAMConfig.sol";

abstract contract SAMConfig is Ownable, ISAMConfig {
    // The royalties fee rate
    uint256 public royaltiesFeeRate;

    // The Fire NFT contract address
    address public fireNftContractAddress;

    // the Revenue address
    address public revenueAddress;

    // The address to burn token
    address public burnAddress;

    // The rate of fee to burn
    uint256 public feeBurnRate;

    // The minimum duration
    uint256 public minDuration;

    // The maximum duration
    uint256 public maxDuration;

    function setRoyaltiesFeeRate(uint256 rate) external onlyOwner {
        royaltiesFeeRate = rate;        
    }

    function setFireNftContractAddress(address _address) external  onlyOwner {
        fireNftContractAddress = _address;
    }

    function setRevenueAddress(address _address) external onlyOwner {
        revenueAddress = _address;
    }

    function setBurnAddress(address _address) external onlyOwner {
        burnAddress = _address;
    }

    function setFeeBurnRate(uint256 _rate) external onlyOwner {
        feeBurnRate = _rate;
    }

    function setMinDuration(uint256 _duration) external onlyOwner {
        minDuration = _duration;        
    }

    function setMaxDuration(uint256 _duration) external onlyOwner {
        maxDuration = _duration;
    }

    function getBurnAddress() external view returns (address) {
        return burnAddress;
    }

    function getRevenueAddress() external view returns (address) {
        return revenueAddress;
    }

    function getFireNftAddress() external view returns (address) {
        return fireNftContractAddress;
    }

    function getRoyalityFeeRate() external view returns (uint256) {
        return royaltiesFeeRate;
    }
}
