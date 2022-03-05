//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBurnToken.sol";

contract BurnToken is IBurnToken, Ownable {
    uint256 public totalBurnAmount;

    IERC20 public tokenContract;

    // The address to burn token
    address public burnAddress;

    uint256 public constant MAXIMUM_FEE_RATE = 5000;
    uint256 public constant FEE_RATE_BASE = 10000;

    // what's the rate of price need to burn
    uint256 public burnRate;

    // minters
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
        _transferOwnership(_owner);
        tokenContract = _token;
        burnAddress = _burnAddress;

        burnRate = 500; // 5%
    }

    function burn(uint256 _price) external override onlyOperator {
        uint256 burnAmount = (burnRate * _price) / FEE_RATE_BASE;
        tokenContract.transfer(burnAddress, burnAmount);
        totalBurnAmount += burnAmount;
    }

    function setOperator(address _account, bool _enable) external onlyOwner {
        require(_account != address(0), "NFT: invalid address");

        operators[_account] = _enable;
    }

    function clearTokens() external onlyOwner {
        uint256 balance = tokenContract.balanceOf(address(this));
        tokenContract.transfer(msg.sender, balance);
    }

    /*
     * @notice Set the burn rate, base is 10000
     * @dev Only callable by owner.
     * @param _rate: the burn rate
     */
    function setBurnRate(uint256 _rate) external onlyOwner {
        require(_rate <= MAXIMUM_FEE_RATE, "Invalid burn rate");
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
