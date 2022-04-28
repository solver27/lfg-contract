// SPDX-License-Identifier: MIT

//** SAM Config Contract */
//** Author Xiao Shengguang : SAM Config Contract 2022.4 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISAMConfig.sol";

contract SAMConfig is Ownable, ISAMConfig {
    uint256 public constant FEE_RATE_BASE = 10000;

    uint256 public constant MAXIMUM_ROYALTIES_FEE_RATE = 5000;

    // The royalties fee rate
    uint256 public royaltiesFeeRate = 500;

    // The Fire NFT contract address
    address public fireNftContractAddress;

    // the Revenue address
    address public revenueAddress;

    // The address to burn token
    address public burnAddress;

    // The rate of fee to burn
    uint256 public feeBurnRate = 5000;

    // The minimum duration
    uint256 public minDuration = 1 days;

    // The maximum duration
    uint256 public maxDuration = 7 days;

    event UpdatedRoyaltiesFeeRate(uint256 rate);
    event UpdatedFireNftContractAddress(address addr);
    event UpdatedRevenueAddress(address addr);
    event UpdatedBurnAddress(address addr);
    event UpdatedFeeBurnRate(uint256 rate);
    event UpdatedMinDuration(uint256 duration);
    event UpdatedMaxDuration(uint256 duration);

    constructor(
        address _owner,
        address _revenueAddress,
        address _burnAddress
    ) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);

        require(_revenueAddress != address(0), "Invalid revenue address");
        revenueAddress = _revenueAddress;

        burnAddress = _burnAddress;
    }

    function setRoyaltiesFeeRate(uint256 rate) external onlyOwner {
        require(rate <= MAXIMUM_ROYALTIES_FEE_RATE, "Invalid royalities fee rate");
        royaltiesFeeRate = rate;
        emit UpdatedRoyaltiesFeeRate(rate);
    }

    function setFireNftContractAddress(address _address) external onlyOwner {
        fireNftContractAddress = _address;
        emit UpdatedFireNftContractAddress(_address);
    }

    function setRevenueAddress(address _address) external onlyOwner {
        require(_address != address(0), "Invalid revenue address");
        revenueAddress = _address;
        emit UpdatedRevenueAddress(_address);
    }

    function setBurnAddress(address _address) external onlyOwner {
        burnAddress = _address;
        emit UpdatedBurnAddress(_address);
    }

    function setFeeBurnRate(uint256 _rate) external onlyOwner {
        require(_rate <= FEE_RATE_BASE, "Invalid fee burn rate");

        feeBurnRate = _rate;
        emit UpdatedFeeBurnRate(_rate);
    }

    function setMinDuration(uint256 _duration) external onlyOwner {
        require(_duration > 0 && _duration < maxDuration, "Invalid minimum duration");
        minDuration = _duration;
        emit UpdatedMinDuration(_duration);
    }

    function setMaxDuration(uint256 _duration) external onlyOwner {
        require(_duration > minDuration, "Invalid maximum duration");

        maxDuration = _duration;
        emit UpdatedMaxDuration(_duration);
    }

    function getBurnAddress() external view override returns (address) {
        return burnAddress;
    }

    function getRevenueAddress() external view override returns (address) {
        return revenueAddress;
    }

    function getFireNftAddress() external view override returns (address) {
        return fireNftContractAddress;
    }

    function getRoyalityFeeRate() external view override returns (uint256) {
        return royaltiesFeeRate;
    }

    function getFeeBurnRate() external view override returns (uint256) {
        return feeBurnRate;
    }

    function getMinDuration() external view override returns (uint256) {
        return minDuration;
    }

    function getMaxDuration() external view override returns (uint256) {
        return maxDuration;
    }

    function getFeeRateBase() external pure override returns (uint256) {
        return FEE_RATE_BASE;
    }
}
