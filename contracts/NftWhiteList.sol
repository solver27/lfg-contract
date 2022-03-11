// SPDX-License-Identifier: MIT

//** NFT Airdrop Contract */
//** Author Xiao Shengguang : NFT Airdrop Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "./interfaces/INftWhiteList.sol";

contract NftWhiteList is Ownable, INftWhiteList {
    event SetNftContractWhitelist(address indexed nftContract, bool isWhitelist);

    // The NFT contract whitelists, only NFT contract whitelisted can sell in the marketplace
    mapping(address => bool) public nftContractWhiteLists;

    // https://eips.ethereum.org/EIPS/eip-721
    bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;

    constructor(address _owner) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);
    }

    function setNftContractWhitelist(address _addr, bool _isWhitelist) external onlyOwner {
        require(_addr != address(0), "Invalid NFT contract address");
        require(
            IERC165(_addr).supportsInterface(_INTERFACE_ID_ERC721),
            "Invalid NFT token contract address"
        );

        nftContractWhiteLists[_addr] = _isWhitelist;

        emit SetNftContractWhitelist(_addr, _isWhitelist);
    }

    function isWhiteListed(address addr) external view override returns (bool) {
        return nftContractWhiteLists[addr];
    }
}
