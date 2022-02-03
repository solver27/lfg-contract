// SPDX-License-Identifier: MIT

//** LFG Vesting Contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NftEscrow is Ownable, ReentrancyGuard {

    event NftDeposit(address indexed sender, address indexed hostContract, uint tokenId);

    event NftWithdraw(address indexed sender, address indexed hostContract, uint tokenId);

    struct nftItem {
        address owner;          // The owner of the NFT
        address hostContract;   // The source of the contract
        uint tokenId;           // The NFT token ID
    }

    mapping (bytes32 => nftItem) nftItems;

    constructor (address _owner) {
        _transferOwnership(_owner);
    }

    function depositNft(address _hostContract, uint _tokenId) external {
        ERC721 nftContract = ERC721(_hostContract);
        nftContract.transferFrom(msg.sender, address(this), _tokenId);

        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));
        nftItems[itemId] = nftItem({owner: msg.sender, hostContract : _hostContract, tokenId : _tokenId });

        emit NftDeposit(msg.sender, _hostContract, _tokenId);
    }

    function withdrawNft(address _hostContract, uint _tokenId) external {
        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));
        require(nftItems[itemId].owner == msg.sender, "The NFT item doesn't belong to the caller");

        ERC721 nftContract = ERC721(_hostContract);
        nftContract.transferFrom(address(this), msg.sender, _tokenId);
        delete nftItems[itemId];

        emit NftWithdraw(msg.sender, _hostContract, _tokenId);
    }
}
