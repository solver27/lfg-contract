// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Base Contract, other marketplace contract will
//** inherit this contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Base Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/INftWhiteList.sol";

/// The contract is abstract so it cannnot be deployed.
abstract contract SAMContractBase is Ownable, ReentrancyGuard, IERC721Receiver {
    enum SellMode {
        FixedPrice,
        Auction,
        DutchAuction
    }

    event ListingPlaced(
        bytes32 indexed listingId,
        address indexed sender,
        address indexed hostContract,
        uint256 tokenId,
        SellMode sellMode,
        uint256 _price,
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

    event RoyaltiesPaid(
        address indexed hostContract,
        uint256 indexed tokenId,
        uint256 royaltiesAmount
    );

    event RoyaltiesFeePaid(
        address indexed hostContract,
        uint256 indexed tokenId,
        uint256 royaltiesFeeAmount
    );

    // https://eips.ethereum.org/EIPS/eip-2981
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    // listing detail
    struct listing {
        address seller; // The owner of the NFT who want to sell it
        address hostContract; // The source of the contract
        uint256 tokenId; // The NFT token ID
        SellMode sellMode; // The sell mode the NFT, fixed price, auction or dutch auction
        uint256 price; // In fixed price sell mode, it is the fixed price, in auction mode, it is the start price
        uint256 startTime; // The timestamp of the listing creation
        uint256 duration; // The duration of the biddings, in seconds
        //bool dutchAuction; // Is this auction a dutch auction
        uint256 discountInterval; // The discount interval, in seconds
        uint256 discountAmount; // The discount amount after every discount interval
        bytes32 biddingId; // last valid bidding Id with highest bidding price
    }

    // bidding detail
    struct bidding {
        address bidder; // User who submit the bidding
        bytes32 listingId; // The target listing id
        uint256 price; // The bidder price
        uint256 timestamp; // The timestamp user create the bidding
    }

    mapping(bytes32 => listing) public listingRegistry; // The mapping of `listing Id` to `listing detail`

    mapping(address => bytes32[]) public addrListingIds; // The mapping of `seller address` to `array of listing Id`

    mapping(bytes32 => bidding) public biddingRegistry; // The mapping of `bidding Id` to `bidding detail`

    mapping(address => bytes32[]) public addrBiddingIds; // The mapping of `bidder address` to `array of bidding Id`

    uint256 public operationNonce;

    uint256 public constant MAXIMUM_FEE_RATE = 5000;
    uint256 public constant FEE_RATE_BASE = 10000;
    uint256 public feeRate;

    // maximum charge 50% royalty fee
    uint256 public constant MAXIMUM_ROYALTIES_FEE_RATE = 5000;

    // The royalties fee rate
    uint256 public royaltiesFeeRate;

    // The Fire NFT contract address
    address public fireNftContractAddress;

    // The nft whitelist contract
    INftWhiteList public nftWhiteListContract;

    struct nftItem {
        address owner; // The owner of the NFT
        address hostContract; // The source of the contract
        uint256 tokenId; // The NFT token ID
    }

    uint256 public totalEscrowAmount;

    /// @notice Checks if NFT contract implements the ERC-2981 interface
    /// @param _contract - the address of the NFT contract to query
    /// @return true if ERC-2981 interface is supported, false otherwise
    function _checkRoyalties(address _contract) internal view returns (bool) {
        bool success = ERC721(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
        return success;
    }

    /*
     * @notice Add NFT to marketplace, Support auction(Price increasing), buyNow (Fixed price) and dutch auction (Price decreasing).
     * @dev Only the token owner can call, because need to transfer the ownership of the token to marketplace contract.
     */
    function _addListing(
        address _hostContract,
        uint256 _tokenId,
        SellMode _sellMode,
        uint256 _price,
        uint256 _startTime,
        uint256 _duration,
        uint256 _discountInterval,
        uint256 _discountAmount
    ) internal {
        require(
            nftWhiteListContract.isWhiteListed(_hostContract),
            "The NFT hosting contract is not in whitelist"
        );

        // Fixed price no need to check start time and duration.
        if (_sellMode != SellMode.FixedPrice) {
            require(_startTime >= block.timestamp, "Listing auction start time past already");
            require(_duration > 0, "Invalid duration");
        }

        if (_sellMode == SellMode.FixedPrice) {
            require(_price > 0, "Invalid fixed price");
        } else if (_sellMode == SellMode.Auction) {
            require(_price > 0, "Invalid auction start price");
        } else if (_sellMode == SellMode.DutchAuction) {
            require(_discountInterval > 0, "Invalid discount interval");
            require(_discountAmount > 0, "Invalid discount amount");
            require(
                _price > (_discountAmount * _duration) / _discountInterval,
                "Start price lower than total discount"
            );
        }

        bytes32 listingId = keccak256(abi.encodePacked(operationNonce, _hostContract, _tokenId));

        _depositNft(msg.sender, _hostContract, _tokenId);

        listingRegistry[listingId].seller = msg.sender;
        listingRegistry[listingId].hostContract = _hostContract;
        listingRegistry[listingId].tokenId = _tokenId;
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
            _hostContract,
            _tokenId,
            _sellMode,
            _price,
            _startTime,
            _duration,
            _discountInterval,
            _discountAmount
        );
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
        require(lst.startTime > 0, "The listing doesn't exist");

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
        require(lst.biddingId == 0, "Already received bidding, cannot close");

        // return the NFT to seller
        _transferNft(msg.sender, lst.hostContract, lst.tokenId);

        _removeListing(listingId, lst.seller);
    }

    function _depositNft(
        address from,
        address _hostContract,
        uint256 _tokenId
    ) internal {
        if (IERC165(_hostContract).supportsInterface(type(IERC721).interfaceId)) {
            ERC721 nftContract = ERC721(_hostContract);
            nftContract.safeTransferFrom(from, address(this), _tokenId);
        } else if (IERC165(_hostContract).supportsInterface(type(IERC1155).interfaceId)) {
            ERC1155 nftContract = ERC1155(_hostContract);
            nftContract.safeTransferFrom(from, address(this), _tokenId, 1, "0x0");
        }
    }

    function _transferNft(
        address to,
        address _hostContract,
        uint256 _tokenId
    ) internal {
        if (IERC165(_hostContract).supportsInterface(type(IERC721).interfaceId)) {
            ERC721 nftContract = ERC721(_hostContract);
            nftContract.safeTransferFrom(address(this), to, _tokenId);
        } else if (IERC165(_hostContract).supportsInterface(type(IERC1155).interfaceId)) {
            ERC1155 nftContract = ERC1155(_hostContract);
            nftContract.safeTransferFrom(address(this), to, _tokenId, 1, "0x0");
        }
    }

    /*
     * @notice Set the Fire NFT contract address, it is a special NFT from gamerse.
     * @dev Only callable by owner.
     * @param _address: the NFT contract to whitelist
     */
    function setFireNftContract(address _address) external onlyOwner {
        require(_address != address(0), "Invalid address");
        fireNftContractAddress = _address;
    }

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * Always returns `IERC1155Receiver.onERC1155Received.selector`.
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /*
     * @notice Set the NFT whitelist contract
     * @dev Only callable by owner.
     * @param _whitelistContract: the contract address which manage the NFT whitelist
     */
    function setNftWhiteListContract(INftWhiteList _whitelistContract) external onlyOwner {
        nftWhiteListContract = _whitelistContract;
    }

    /*
     * @notice Update the fee rate and burn fee rate from the burn amount
     * @dev Only callable by owner.
     * @param _feeRate: the fee rate the contract charge.
     * @param _royaltiesFeeRate: the royalties fee rate the contract charge.
     */
    function updateFeeRate(uint256 _feeRate, uint256 _royaltiesFeeRate) external onlyOwner {
        require(_feeRate <= MAXIMUM_FEE_RATE, "Invalid fee rate");
        require(_royaltiesFeeRate <= MAXIMUM_ROYALTIES_FEE_RATE, "Invalid royalty fee rate");

        feeRate = _feeRate;
        royaltiesFeeRate = _royaltiesFeeRate;
    }
}
