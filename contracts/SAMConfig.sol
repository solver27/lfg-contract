// SPDX-License-Identifier: MIT

//** NFT Airdrop Contract */
//** Author Xiao Shengguang : NFT Airdrop Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ISAMConfig.sol";

contract SAMConfig is Ownable, ISAMConfig {
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
        
    }
}
