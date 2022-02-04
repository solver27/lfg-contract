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

    event ListingPlaced(address indexed sender, address indexed hostContract, uint tokenId,
        uint auctionStartPrice, uint buyNowPrice, string uri);

    struct bidding {
        address bidder;         // User who submit the bidding
        uint price;             // The bidder price
        uint timestamp;         // The timestamp user create the bidding
    }

    struct listingInfo {
        address seller;         // The owner of the NFT who want to sell it
        address hostContract;   // The source of the contract
        uint tokenId;           // The NFT token ID
        uint auctionStartPrice; // The auction start price
        uint buyNowPrice;       // The price user can directly buy the NFT
        uint timestamp;         // The timestamp of the listing creation
        uint auctionDuration;   // The duration of the biddings, in seconds
    }

    struct listing {
        listingInfo info;
        address seller;         // The owner of the NFT who want to sell it
        address hostContract;   // The source of the contract
        uint tokenId;           // The NFT token ID
        uint auctionStartPrice; // The auction start price
        uint buyNowPrice;       // The price user can directly buy the NFT
        uint timestamp;         // The timestamp of the listing creation
        uint auctionDuration;   // The duration of the biddings, in seconds
        mapping(uint => bidding) biddings; // The bidding of the listing, to workaround the array issue
        uint countOfBidding;    // The count of bidding
    }

    struct listings {
        mapping(uint => listing) lists;
        uint countOfLists;
    }

    address operator;

    address [] addresses;

    mapping (address => listings) addrNftListing;

    constructor (address _owner) {
        _transferOwnership(_owner);
    }

    function setOperator(address _operator) onlyOwner external
    {
        operator = _operator;
    }

    function addListing(address _hostContract, uint _tokenId, uint _startPrice, uint _buyNowPrice, uint _duration) external {
        //bytes32 listingId = keccak256(abi.encodePacked(listingNonce, _hostContract, _tokenId));

        // listing memory lst = listing({seller: msg.sender, hostContract : _hostContract, tokenId : _tokenId, auctionStartPrice : _startPrice,
        //     buyNowPrice : _buyNowPrice, timestamp : block.timestamp, auctionDuration : _duration, countOfBidding: 0 });
        //bidding[] storage biddings;
        //bidding[] memory biddings = new bidding[](1);
        //listing memory lst;// = listing(msg.sender, _hostContract, _tokenId, _startPrice, _buyNowPrice, block.timestamp, _duration, biddings);
        //nftListing[listingId] = lst;
        //listingNonce += 1;

        addrNftListing[msg.sender].countOfLists = 0;
        uint id = addrNftListing[msg.sender].countOfLists;
        addrNftListing[msg.sender].lists[id].seller = msg.sender;
        addrNftListing[msg.sender].lists[id].hostContract = _hostContract;
        addrNftListing[msg.sender].lists[id].tokenId = _tokenId;
        addrNftListing[msg.sender].lists[id].auctionStartPrice = _startPrice;
        addrNftListing[msg.sender].lists[id].buyNowPrice = _buyNowPrice;
        addrNftListing[msg.sender].lists[id].timestamp = block.timestamp;
        addrNftListing[msg.sender].lists[id].auctionDuration = _duration;
        addrNftListing[msg.sender].countOfLists++;

        addresses.push(msg.sender);

        // nftListing[listingId].seller = msg.sender;
        // nftListing[listingId].hostContract = _hostContract;
        // nftListing[listingId].tokenId = _tokenId;
        // nftListing[listingId].auctionStartPrice = _startPrice;
        // nftListing[listingId].buyNowPrice = _buyNowPrice;
        // nftListing[listingId].timestamp = block.timestamp;
        // nftListing[listingId].auctionDuration = _duration;

        ERC721 hostContract = ERC721(_hostContract);
        string memory uri = hostContract.tokenURI(_tokenId);
        emit ListingPlaced(msg.sender, _hostContract, _tokenId, _startPrice, _buyNowPrice, uri);
    }

    function listingOfAddr(address addr) public view returns(listingInfo[] memory)
    {
        listingInfo[] memory infoLists = new listingInfo[](addrNftListing[addr].countOfLists);
        for (uint i = 0; i < addrNftListing[addr].countOfLists; ++i) {
            //listings.push(addrNftListing[addr].lists[i]);
            //listing storage lst = addrNftListing[addr].lists[i];
            infoLists[i] = addrNftListing[addr].lists[i].info;
        }
        return infoLists;
    }
}

