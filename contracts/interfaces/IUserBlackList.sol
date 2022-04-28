// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IUserBlackList {
    function isBlackListed(address addr) view external returns(bool);
}
