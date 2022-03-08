//SPDX-License-Identifier: MIT

//** BurnToken Contract, burn some ratio of token by the given price */
//** Author Xiao Shengguang : BurnToken Contract 2022.3 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBurnToken.sol";

contract BurnToken is IBurnToken, Ownable {
    uint256 public totalBurnAmount;

    // The token contract address
    IERC20 public tokenContract;

    // The address to burn token
    address public burnAddress;

    uint256 public constant MAXIMUM_BURN_RATE = 5000;
    uint256 public constant RATE_BASE = 10000;

    // what's the rate of price need to burn
    uint256 public burnRate;

    // operators can burn tokens
    mapping(address => bool) public operators;

    modifier onlyOperator() {
        require(operators[msg.sender], "Invalid operator");
        _;
    }

    constructor(
        address _owner,
        IERC20 _token,
        address _burnAddress
    ) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);
        tokenContract = _token;
        burnAddress = _burnAddress;

        burnRate = 500; // 5%
    }

    /*
     * @notice Burn _price * burnRate / RATE_BASE of token
     * @dev Only callable by operators.
     * @param _price: the sell price of NFT.
     */
    function burn(uint256 _price) external override onlyOperator {
        uint256 burnAmount = (burnRate * _price) / RATE_BASE;
        if (burnAmount > 0) {
            tokenContract.transfer(burnAddress, burnAmount);
            totalBurnAmount += burnAmount;
        }
    }

    /*
     * @notice Enable/Disable an address as an operator, only enabled operator can burn token
     * @dev Only callable by owner.
     * @param _account: The address to enable/disable.
     * @param _enable: Enable or disable the operator.
     */
    function setOperator(address _account, bool _enable) external onlyOwner {
        require(_account != address(0), "NFT: invalid address");
        operators[_account] = _enable;
    }

    /*
     * @notice Claim back all the unburned tokens
     * @dev Only callable by owner.
     */
    function clearTokens() external onlyOwner {
        uint256 balance = tokenContract.balanceOf(address(this));
        if (balance > 0) {
            tokenContract.transfer(msg.sender, balance);
        }
    }

    /*
     * @notice Set the burn rate, base is 10000
     * @dev Only callable by owner.
     * @param _rate: the burn rate
     */
    function setBurnRate(uint256 _rate) external onlyOwner {
        require(_rate <= MAXIMUM_BURN_RATE, "Invalid burn rate");
        burnRate = _rate;
    }

    /*
     * @notice Set the burn address
     * @dev Only callable by owner.
     * @param _burnAddress: the burn address
     */
    function setBurnAddress(address _burnAddress) external onlyOwner {
        burnAddress = _burnAddress;
    }
}
