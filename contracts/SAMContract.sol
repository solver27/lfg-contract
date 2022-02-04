// SPDX-License-Identifier: MIT

//** LFG Vesting Contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SAMContract is Ownable, ReentrancyGuard {

    event ListingPlaced(bytes32 indexed listingId, address indexed sender, address indexed hostContract, uint tokenId,
        uint auctionStartPrice, uint buyNowPrice, string uri);

    event BiddingPlaced(bytes32 indexed biddingId, bytes32 listingId, uint price);

    struct listing {
        address seller;         // The owner of the NFT who want to sell it
        address hostContract;   // The source of the contract
        uint tokenId;           // The NFT token ID
        uint auctionStartPrice; // The auction start price
        uint buyNowPrice;       // The price user can directly buy the NFT
        uint timestamp;         // The timestamp of the listing creation
        uint auctionDuration;   // The duration of the biddings, in seconds
        bytes32[] biddingIds;   // The array of the bidding Ids
    }

    struct bidding {
        address bidder;         // User who submit the bidding
        uint price;             // The bidder price
        uint timestamp;         // The timestamp user create the bidding
    }

    address [] userAddresses;

    mapping (bytes32 => listing) listingRegistry;   // The mapping of listing Id to listing details

    mapping (address => bytes32[]) addrListingIds;  // The mapping of the listings of address

    mapping (bytes32 => bidding) biddingRegistry;   // The mapping of bidding Id to bidding details

    mapping (address => bytes32[]) addrBiddingIds;  // The mapping of the bidding of address

    uint operationNonce;

    IERC20 public _lfgToken;

    constructor (address _owner, IERC20 _token) {
        _transferOwnership(_owner);
        _lfgToken = _token;
    }

    function addListing(address _hostContract, uint _tokenId, uint _startPrice, uint _buyNowPrice, uint _duration) external {
        // TODO: transfer the NFT to Escrow contract

        bytes32 listingId = keccak256(abi.encodePacked(operationNonce, _hostContract, _tokenId));

        listingRegistry[listingId].seller = msg.sender;
        listingRegistry[listingId].hostContract = _hostContract;
        listingRegistry[listingId].tokenId = _tokenId;
        listingRegistry[listingId].auctionStartPrice = _startPrice;
        listingRegistry[listingId].buyNowPrice = _buyNowPrice;
        listingRegistry[listingId].timestamp = block.timestamp;
        listingRegistry[listingId].auctionDuration = _duration;
        operationNonce++;

        addrListingIds[msg.sender].push(listingId);

        userAddresses.push(msg.sender);

        ERC721 hostContract = ERC721(_hostContract);
        string memory uri = hostContract.tokenURI(_tokenId);
        emit ListingPlaced(listingId, msg.sender, _hostContract, _tokenId, _startPrice, _buyNowPrice, uri);
    }

    function listingOfAddr(address addr) public view returns(listing[] memory)
    {
        listing[] memory resultlistings = new listing[](addrListingIds[addr].length);
        for (uint i = 0; i < addrListingIds[addr].length; ++i) {
            bytes32 listingId = addrListingIds[addr][i];
            resultlistings[i] = listingRegistry[listingId];
        }
        return resultlistings;
    }

    function placeBid(bytes32 listingId, uint price) external {
        listing storage lst = listingRegistry[listingId];
        require(lst.timestamp + lst.auctionDuration > block.timestamp, "The listing is expired");

        require(price > lst.auctionStartPrice, "Bid price should larger than the auction start price");

        // TODO: transfer the price amount of LFG token to Escrow contract

        bytes32 biddingId = keccak256(abi.encodePacked(operationNonce, lst.hostContract, lst.tokenId));
        biddingRegistry[biddingId].bidder = msg.sender;
        biddingRegistry[biddingId].price = price;
        biddingRegistry[biddingId].timestamp = block.timestamp;

        lst.biddingIds.push(biddingId);

        addrBiddingIds[msg.sender].push(biddingId);

        emit BiddingPlaced(biddingId, listingId, price);
    }

    function biddingOfListing(bytes32 listingId) public view returns (bidding[] memory) {
        listing storage lst = listingRegistry[listingId];
        bidding[] memory bids = new bidding[](lst.biddingIds.length);
        for (uint i = 0; i < lst.biddingIds.length; ++i) {
            bytes32 biddingId = lst.biddingIds[i];
            bids[i] = biddingRegistry[biddingId];
        }
        return bids;
    }

    function biddingOfAddr(address addr) public view returns(bidding[] memory)
    {
        bidding[] memory biddings = new bidding[](addrBiddingIds[addr].length);
        for (uint i = 0; i < addrBiddingIds[addr].length; ++i) {
            bytes32 biddingId = addrBiddingIds[addr][i];
            biddings[i] = biddingRegistry[biddingId];
        }
        return biddings;
    }
}
