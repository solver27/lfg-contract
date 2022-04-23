// SPDX-License-Identifier: MIT

//** NFT Whitelist Contract */
//** Author Xiao Shengguang : NFT Whitelist Contract 2022.1 */
//** Only whitelisted NFT contract can sell on marketplace  */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interfaces/INftWhiteList.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract NftWhiteList is Ownable, INftWhiteList {
    event SetNftContractWhitelist(address indexed nftContract, bool isWhitelist);

    // The NFT contract whitelists, only NFT contract whitelisted can sell in the marketplace
    mapping(address => bool) public nftContractWhiteLists;

    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);
    }

    function setNftContractWhitelist(address _addr, bool _isWhitelist) external onlyOwner {
        require(_addr != address(0), "Invalid NFT contract address");
        require(
            IERC165(_addr).supportsInterface(type(IERC721).interfaceId) ||
                IERC165(_addr).supportsInterface(type(IERC1155).interfaceId),
            "Invalid NFT token contract address"
        );

        nftContractWhiteLists[_addr] = _isWhitelist;

        emit SetNftContractWhitelist(_addr, _isWhitelist);
    }

    function isWhiteListed(address addr) external view override returns (bool) {
        return nftContractWhiteLists[addr];
    }
}
