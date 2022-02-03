// SPDX-License-Identifier: MIT

//** LFG Vesting Contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SAMContract is Ownable, ReentrancyGuard {

    event ListingPlaced(bytes32 indexed listingId, address indexed hostContract, address indexed sender, uint tokenId,
        uint auctionStartPrice, uint buyNowPrice, string uri);

    struct bidding {
        address bidder;         // User who submit the bidding
        uint price;             // The bidder price
        uint timestamp;         // The timestamp user create the bidding
    }

    struct listing {
        address seller;         // The owner of the NFT who want to sell it
        address hostContract;   // The source of the contract
        uint tokenId;           // The NFT token ID
        uint auctionStartPrice; // The auction start price
        uint buyNowPrice;       // The price user can directly buy the NFT
        uint timestamp;         // The timestamp of the listing creation
        uint auctionDuration;   // The duration of the biddings, in seconds
        bidding [] biddings;    // The list of biddings
    }

    address operator;

    uint listingNonce;
    mapping (bytes32 => listing) nftListing;

    constructor (address _owner) {
        _transferOwnership(_owner);
    }

    function setOperator(address _operator) onlyOwner external
    {
        operator = _operator;
    }

    function addListing(address _seller, address _hostContract, uint _tokenId, uint _startPrice, uint _buyNowPrice, uint _duration) external {
        bytes32 listingId = keccak256(abi.encodePacked(listingNonce, _hostContract, _tokenId));
        nftListing[listingId].seller = _seller;
        nftListing[listingId].hostContract = _hostContract;
        nftListing[listingId].tokenId = _tokenId;
        nftListing[listingId].auctionStartPrice = _startPrice;
        nftListing[listingId].buyNowPrice = _buyNowPrice;
        nftListing[listingId].timestamp = block.timestamp;
        nftListing[listingId].auctionDuration = _duration;
        listingNonce += 1;
        ERC721 hostContract = ERC721(nftListing[listingId].hostContract);
        string memory uri = hostContract.tokenURI(_tokenId);
        emit ListingPlaced(listingId, _hostContract, _seller, _tokenId, _startPrice, _buyNowPrice, uri);
    }
}
