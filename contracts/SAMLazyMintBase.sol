// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Base Contract, other marketplace contract will
//** inherit this contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Base Contract 2022.1 */

pragma solidity ^0.8.0;

import "./LFGNFT1155.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// The contract is abstract so it cannnot be deployed.
abstract contract SAMLazyMintBase is Ownable, ReentrancyGuard {
    enum SellMode {
        FixedPrice,
        Auction,
        DutchAuction
    }

    event ListingPlaced(
        bytes32 indexed listingId,
        address indexed sender,
        bytes collectionTag,
        uint256 tokenId,
        SellMode sellMode,
        uint256 price,
        uint256 startTime,
        uint256 duration,
        uint256 discountInterval,
        uint256 discountAmount
    );

    event ListingRemoved(bytes32 indexed listingId, address indexed sender);

    event BiddingRemoved(bytes32 indexed biddingId, address indexed sender);

    event BiddingPlaced(bytes32 indexed biddingId, bytes32 listingId, uint256 price);

    event BuyNow(bytes32 indexed listingId, address indexed buyer, uint256 price);

    event ClaimNFT(bytes32 indexed listingId, bytes32 indexed biddingId, address indexed buyer);

    event MintToBuyer(address indexed buyer, uint256 indexed tokenId, bytes data);

    // https://eips.ethereum.org/EIPS/eip-2981
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    struct listing {
        bytes32 id; // The listing id
        address seller; // The owner of the NFT who want to sell it
        bytes collectionTag; // The collection tag
        uint256 tokenId;
        SellMode sellMode; // The sell mode the NFT, fixed price, auction or dutch auction
        uint256 price; // In fixed price sell mode, it is the fixed price, in auction mode, it is the start price
        uint256 startTime; // The timestamp of the listing creation
        uint256 duration; // The duration of the biddings, in seconds
        //bool dutchAuction; // Is this auction a dutch auction
        uint256 discountInterval; // The discount interval, in seconds
        uint256 discountAmount; // The discount amount after every discount interval
        bytes32[] biddingIds; // The array of the bidding Ids
    }

    struct bidding {
        bytes32 id; // The bidding id
        address bidder; // User who submit the bidding
        bytes32 listingId; // The target listing id
        uint256 price; // The bidder price
        uint256 timestamp; // The timestamp user create the bidding
    }

    mapping(bytes32 => listing) public listingRegistry; // The mapping of listing Id to listing details

    mapping(address => bytes32[]) public addrListingIds; // The mapping of the listings of address

    mapping(bytes32 => bidding) public biddingRegistry; // The mapping of bidding Id to bidding details

    mapping(address => bytes32[]) public addrBiddingIds; // The mapping of the bidding of address

    uint256 public operationNonce;

    uint256 public constant MAXIMUM_FEE_RATE = 5000;
    uint256 public constant FEE_RATE_BASE = 10000;
    uint256 public feeRate;

    // maximum charge 50% royalty fee
    uint256 public constant MAXIMUM_ROYALTIES_FEE_RATE = 5000;

    // The total escrow amount of customer assets
    uint256 public totalEscrowAmount;

    // The hosting NFT contract
    LFGNFT1155 public nftContract;

    // The revenue address
    address public revenueAddress;

    // Total revenue amount
    uint256 public revenueAmount;

    /*
     * @notice Add NFT to marketplace, Support auction(Price increasing), buyNow (Fixed price) and dutch auction (Price decreasing).
     * @dev Only the token owner can call, because need to transfer the ownership of the token to marketplace contract.
     */
    function _addListing(
        bytes calldata _collectionTag,
        SellMode _sellMode,
        uint256 _price,
        uint256 _startTime,
        uint256 _duration,
        uint256 _discountInterval,
        uint256 _discountAmount
    ) internal {
        require(_startTime >= block.timestamp, "Listing auction start time past already");
        require(_duration > 0, "Invalid duration");

        if (_sellMode == SellMode.FixedPrice) {
            require(_price > 0, "Invalid fixed price");
        } else if (_sellMode == SellMode.Auction) {
            require(_price > 0, "Invalid auction start price");
        } else if (_sellMode == SellMode.DutchAuction) {
            require(_discountInterval > 0, "Invalid discount interval");
            require(_discountAmount > 0, "Invalid discount amount");
            uint256 discount = (_discountAmount * _duration) / _discountInterval;
            require(_price > discount, "Start price lower than total discount");
        }

        // create the token, but not mint it
        uint256 tokenId = nftContract.create(msg.sender, 0, _collectionTag);

        bytes32 listingId = keccak256(abi.encodePacked(operationNonce, _collectionTag, tokenId));

        listingRegistry[listingId].id = listingId;
        listingRegistry[listingId].seller = msg.sender;
        listingRegistry[listingId].collectionTag = _collectionTag;
        listingRegistry[listingId].tokenId = tokenId;
        listingRegistry[listingId].sellMode = _sellMode;
        listingRegistry[listingId].price = _price;
        listingRegistry[listingId].startTime = _startTime;
        listingRegistry[listingId].duration = _duration;
        listingRegistry[listingId].discountInterval = _discountInterval;
        listingRegistry[listingId].discountAmount = _discountAmount;
        operationNonce++;

        addrListingIds[msg.sender].push(listingId);

        emit ListingPlaced(
            listingId,
            msg.sender,
            _collectionTag,
            tokenId,
            _sellMode,
            _price,
            _startTime,
            _duration,
            _discountInterval,
            _discountAmount
        );
    }

    function _buyNow(bytes32 listingId) internal {
        listing storage lst = listingRegistry[listingId];
        require(lst.sellMode != SellMode.Auction, "Auction not support buy now");
        // Only check for dutch auction, for fixed price there is no duration
        if (lst.sellMode == SellMode.DutchAuction) {
            require(block.timestamp >= lst.startTime, "The auction haven't start");
            require(lst.startTime + lst.duration >= block.timestamp, "The auction already expired");
        }
        require(msg.sender != lst.seller, "Buyer cannot be seller");

        uint256 price = getPrice(listingId);

        _processFee(price);

        // Deposit the tokens to market place contract.
        _depositToken(price);

        uint256 sellerAmount = price;

        _transferToken(msg.sender, lst.seller, sellerAmount);

        _mintToBuyer(msg.sender, lst.tokenId, lst.collectionTag);

        emit BuyNow(listingId, msg.sender, price);

        _removeListing(listingId, lst.seller);
    }

    function _placeBid(bytes32 listingId, uint256 price) internal {
        listing storage lst = listingRegistry[listingId];
        require(lst.sellMode == SellMode.Auction, "Can only bid for listing on auction");
        require(block.timestamp >= lst.startTime, "The auction haven't start");
        require(lst.startTime + lst.duration >= block.timestamp, "The auction already expired");
        require(msg.sender != lst.seller, "Bidder cannot be seller");

        uint256 minPrice = lst.price;
        // The last element is the current highest price
        if (lst.biddingIds.length > 0) {
            bytes32 lastBiddingId = lst.biddingIds[lst.biddingIds.length - 1];
            minPrice = biddingRegistry[lastBiddingId].price;
        }

        require(price > minPrice, "Bid price too low");

        _depositToken(price);

        bytes32 biddingId = keccak256(abi.encodePacked(operationNonce, lst.tokenId, price));

        biddingRegistry[biddingId].id = biddingId;
        biddingRegistry[biddingId].bidder = msg.sender;
        biddingRegistry[biddingId].listingId = listingId;
        biddingRegistry[biddingId].price = price;
        biddingRegistry[biddingId].timestamp = block.timestamp;

        operationNonce++;

        lst.biddingIds.push(biddingId);

        addrBiddingIds[msg.sender].push(biddingId);

        emit BiddingPlaced(biddingId, listingId, price);
    }

    function _claimNft(bytes32 biddingId) internal {
        bidding storage bid = biddingRegistry[biddingId];
        require(bid.bidder == msg.sender, "Only bidder can claim NFT");

        listing storage lst = listingRegistry[bid.listingId];
        require(
            lst.startTime + lst.duration < block.timestamp,
            "The bidding period haven't complete"
        );
        for (uint256 i = 0; i < lst.biddingIds.length; ++i) {
            bytes32 tmpId = lst.biddingIds[i];
            if (biddingRegistry[tmpId].price > bid.price) {
                require(false, "The bidding is not the highest price");
            }
        }

        _processFee(bid.price);

        uint256 sellerAmount = bid.price;

        _transferToken(msg.sender, lst.seller, sellerAmount);

        _mintToBuyer(msg.sender, lst.tokenId, lst.collectionTag);

        emit ClaimNFT(lst.id, biddingId, msg.sender);

        // Refund the failed bidder
        for (uint256 i = 0; i < lst.biddingIds.length; ++i) {
            bytes32 tmpId = lst.biddingIds[i];
            if (tmpId != biddingId) {
                _transferToken(
                    biddingRegistry[tmpId].bidder,
                    biddingRegistry[tmpId].bidder,
                    biddingRegistry[tmpId].price
                );
            }
        }

        _removeListing(lst.id, lst.seller);
        _removeBidding(biddingId, bid.bidder);
    }

    function _mintToBuyer(
        address _buyer,
        uint256 tokenId,
        bytes memory data
    ) internal {
        nftContract.mint(_buyer, tokenId, 1, data);

        emit MintToBuyer(_buyer, tokenId, data);
    }

    function listingOfAddr(address addr) public view returns (bytes32[] memory) {
        return addrListingIds[addr];
    }

    /*
     * @notice Get the price of Dutch auction and fixed price item.
     * @dev Not support auction item which need to get from the lastest bid.
     * @param listingId: the listing item id.
     */
    function getPrice(bytes32 listingId) public view returns (uint256) {
        listing storage lst = listingRegistry[listingId];
        require(lst.price > 0, "The listing doesn't exist");

        if (lst.sellMode == SellMode.DutchAuction) {
            uint256 timeElapsed;
            // If the auction haven't start, then already return the start price
            if (lst.startTime >= block.timestamp) {
                return lst.price;
            }

            timeElapsed = block.timestamp - lst.startTime;
            // If the time elapsed exceed duration, then using the duration, because after duration the
            // price shouldn't drop.
            if (timeElapsed > lst.duration) {
                timeElapsed = lst.duration;
            }
            uint256 discount = lst.discountAmount * (timeElapsed / lst.discountInterval);
            return lst.price - discount;
        }

        return lst.price;
    }

    /*
     * @notice Get all the biddings of an address.
     * @param addr: the address want to get.
     */
    function biddingOfAddr(address addr) public view returns (bytes32[] memory) {
        return addrBiddingIds[addr];
    }

    function _removeItemFromArray(bytes32 listingId, bytes32[] storage arrayOfIds) internal {
        uint256 length = arrayOfIds.length;
        for (uint256 index = 0; index < length; ++index) {
            // Move the last element to the index need to remove
            if (arrayOfIds[index] == listingId && index != length - 1) {
                arrayOfIds[index] = arrayOfIds[length - 1];
            }
        }
        // Remove the last element
        arrayOfIds.pop();
    }

    function _removeListing(bytes32 listingId, address seller) internal {
        _removeItemFromArray(listingId, addrListingIds[seller]);

        // Delete from the mapping
        delete listingRegistry[listingId];

        emit ListingRemoved(listingId, seller);
    }

    function _removeBidding(bytes32 biddingId, address bidder) internal {
        _removeItemFromArray(biddingId, addrBiddingIds[bidder]);

        // Delete from the mapping
        delete biddingRegistry[biddingId];

        emit BiddingRemoved(biddingId, bidder);
    }

    /*
     * @notice Remove a listing from the marketplace, can only remove if the duration finished and
     *         the item didn't receive any bid(For auction item).
     * @param listingId: the listing want to remove.
     */
    function removeListing(bytes32 listingId) external nonReentrant {
        listing storage lst = listingRegistry[listingId];
        // For fixed price sell, there is no duration limit,
        // so user should be remove it any time before it is sold.
        if (lst.sellMode != SellMode.FixedPrice) {
            require(lst.startTime + lst.duration < block.timestamp, "The listing haven't expired");
        }
        require(lst.seller == msg.sender, "Only seller can remove");
        require(lst.biddingIds.length == 0, "Already received bidding, cannot close");

        _removeListing(lst.id, lst.seller);
    }

    /*
     * @notice Update the transaction fee rate
     * @dev Only callable by owner.
     * @param _feeRate: the fee rate the contract charge.
     */
    function updateFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate <= MAXIMUM_FEE_RATE, "Invalid fee rate");
        feeRate = _feeRate;
    }

    /*
     * @notice Process fee which is the revenue, some will burn if using LFG token.
     * @param _price: The price of buy or bidding.
     */
    function _processFee(uint256 _price) internal virtual;

    /*
     * @notice User deposit the token for bidding, which will under escrow
     * @param _amount: The amount to deposit.
     */
    function _depositToken(uint256 _amount) internal virtual;

    /*
     * @notice Transfer token from one address to another address, if they
               are the same, means refund the escrowed token
     * @param _from: The token transfer from.
     * @param _to: The token transfer to.
     * @param _from: The amount to transfer.
     */
    function _transferToken(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual;
}
