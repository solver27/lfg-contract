// SPDX-License-Identifier: MIT

//** User Whitelist Contract */
//** Author Xiao Shengguang : User Whitelist Contract 2022.1 */
//** Blacklisted user cannot mint or transfer NFT            */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IUserBlackList.sol";

contract UserBlackList is Ownable, IUserBlackList {
    event SetUserBlackList(address indexed addr, bool isWhitelist);

    event SetOperator(address indexed addr, bool isOperator);

    // The user contract whitelists, only whitelisted user can mint on the NFT contract
    mapping(address => bool) public userBlackLists;

    mapping(address => bool) public operators;

    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);
    }

    modifier onlyOperatorOrOwner() {
        require(operators[msg.sender] || msg.sender == owner(), "Invalid operator or owner");
        _;
    }

    function setOperator(address _account, bool _isOperator) external onlyOwner {
        require(_account != address(0), "Invalid address");

        operators[_account] = _isOperator;

        emit SetOperator(_account, _isOperator);
    }

    function setUserBlackList(address[] calldata _addresses, bool[] calldata _isBlackList)
        external
        onlyOperatorOrOwner
    {
        require(_addresses.length == _isBlackList.length, "Invalid array length");

        for (uint256 i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != address(0), "Invalid user address");

            userBlackLists[_addresses[i]] = _isBlackList[i];

            emit SetUserBlackList(_addresses[i], _isBlackList[i]);
        }
    }

    function isBlackListed(address addr) external view override returns (bool) {
        return userBlackLists[addr];
    }
}
