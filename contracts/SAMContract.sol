// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IERC2981.sol";
import "./interfaces/IBurnToken.sol";
import "./interfaces/INftWhiteList.sol";

contract SAMContract is Ownable, ReentrancyGuard, IERC721Receiver {
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
        uint256 startPrice,
        uint256 buyNowPrice,
        uint256 startTime,
        uint256 duration,
        uint256 discountInterval,
        uint256 discountAmount
    );

    event ListingRemoved(bytes32 indexed listingId, address indexed sender);

    event BiddingPlaced(bytes32 indexed biddingId, bytes32 listingId, uint256 price);

    event BuyNow(bytes32 indexed listingId, address indexed buyer, uint256 price);

    event ClaimNFT(bytes32 indexed listingId, bytes32 indexed biddingId, address indexed buyer);

    event NftDeposit(address indexed sender, address indexed hostContract, uint256 tokenId);

    event NftTransfer(address indexed sender, address indexed hostContract, uint256 tokenId);

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

    struct listing {
        bytes32 id; // The listing id
        address seller; // The owner of the NFT who want to sell it
        address hostContract; // The source of the contract
        uint256 tokenId; // The NFT token ID
        SellMode sellMode; // The sell mode the NFT, fixed price, auction or dutch auction
        uint256 startPrice; // The auction start price
        uint256 buyNowPrice; // The price user can directly buy the NFT
        uint256 startTime; // The timestamp of the listing creation
        uint256 auctionDuration; // The duration of the biddings, in seconds
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

    uint256 operationNonce;

    uint256 public constant MAXIMUM_FEE_RATE = 5000;
    uint256 public constant FEE_RATE_BASE = 10000;
    uint256 public feeRate;

    uint256 public constant MAXIMUM_FEE_BURN_RATE = 10000; // maximum burn 100% of the fee

    // The rate of fee to burn
    uint256 public feeBurnRate;

    // maximum charge 50% royalty fee
    uint256 public constant MAXIMUM_ROYALTIES_FEE_RATE = 5000;

    // The royalties fee rate
    uint256 public royaltiesFeeRate;

    // The address to burn token
    address public burnAddress;

    uint256 public totalBurnAmount;

    // The revenue address
    address public revenueAddress;

    // Total revenue amount
    uint256 public revenueAmount;

    // The Fire NFT contract address
    address public fireNftContractAddress;

    //address public burnFromAddress;
    IBurnToken public burnTokenContract;

    // The nft whitelist contract
    INftWhiteList public nftWhiteListContract;

    IERC20 public lfgToken;

    struct nftItem {
        address owner; // The owner of the NFT
        address hostContract; // The source of the contract
        uint256 tokenId; // The NFT token ID
    }

    mapping(bytes32 => nftItem) public nftItems;

    struct userToken {
        uint256 lockedAmount;
    }

    mapping(address => userToken) public addrTokens;

    uint256 public totalEscrowAmount;

    constructor(
        address _owner,
        IERC20 _lfgToken,
        INftWhiteList _nftWhiteList,
        address _burnAddress,
        address _revenueAddress
    ) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);
        lfgToken = _lfgToken;
        nftWhiteListContract = _nftWhiteList;
        burnAddress = _burnAddress;
        revenueAddress = _revenueAddress;

        feeRate = 250; // 2.5%
        feeBurnRate = 5000; // 50%
        royaltiesFeeRate = 1000; // Default 10% royalties fee.
    }

    /// @notice Checks if NFT contract implements the ERC-2981 interface
    /// @param _contract - the address of the NFT contract to query
    /// @return true if ERC-2981 interface is supported, false otherwise
    function _checkRoyalties(address _contract) internal view returns (bool) {
        bool success = ERC721(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
        return success;
    }

    function _deduceRoyalties(
        address _contract,
        uint256 tokenId,
        uint256 grossSaleValue
    ) internal returns (uint256 netSaleAmount) {
        // Get amount of royalties to pays and recipient
        (address royaltiesReceiver, uint256 royaltiesAmount) = IERC2981(_contract).royaltyInfo(
            tokenId,
            grossSaleValue
        );
        // Deduce royalties from sale value
        uint256 netSaleValue = grossSaleValue - royaltiesAmount;
        // Transfer royalties to rightholder if not zero
        if (royaltiesAmount > 0) {
            uint256 royaltyFee = (royaltiesAmount * royaltiesFeeRate) / FEE_RATE_BASE;
            if (royaltyFee > 0) {
                _transferToken(msg.sender, revenueAddress, royaltyFee);
                revenueAmount += royaltyFee;

                emit RoyaltiesFeePaid(_contract, tokenId, royaltyFee);
            }

            uint256 payToReceiver = royaltiesAmount - royaltyFee;
            _transferToken(msg.sender, royaltiesReceiver, payToReceiver);

            // Broadcast royalties payment
            emit RoyaltiesPaid(_contract, tokenId, payToReceiver);
        }

        return netSaleValue;
    }

    /*
     * @notice Update the fee rate and burn fee rate from the burn amount
     * @dev Only callable by owner.
     * @param _fee: the fee rate
     * @param _burnRate: the burn fee rate
     */
    function updateFeeRate(
        uint256 _feeRate,
        uint256 _feeBurnRate,
        uint256 _royaltiesFeeRate
    ) external onlyOwner {
        require(_feeRate <= MAXIMUM_FEE_RATE, "Invalid fee rate");
        require(_feeBurnRate <= FEE_RATE_BASE, "Invalid fee burn rate");
        require(_royaltiesFeeRate <= MAXIMUM_ROYALTIES_FEE_RATE, "Invalid royalty fee rate");

        feeRate = _feeRate;
        feeBurnRate = _feeBurnRate;
        royaltiesFeeRate = _royaltiesFeeRate;
    }

    /*
     * @notice Add NFT to marketplace, Support auction(Price increasing), buyNow (Fixed price) and dutch auction (Price decreasing).
     * @dev Only the token owner can call, because need to transfer the ownership to marketplace contract.
     */
    function addListing(
        address _hostContract,
        uint256 _tokenId,
        SellMode _sellMode,
        uint256 _startPrice,
        uint256 _buyNowPrice,
        uint256 _startTime,
        uint256 _duration,
        uint256 _discountInterval,
        uint256 _discountAmount
    ) external nonReentrant {
        require(
            nftWhiteListContract.isWhiteListed(_hostContract),
            "The NFT hosting contract is not in whitelist"
        );
        require(_startTime >= block.timestamp, "Listing auction start time past already");
        require(_duration > 0, "Invalid duration");

        if (_sellMode == SellMode.FixedPrice) {
            require(_buyNowPrice > 0, "Invalid fixed price");
        } else if (_sellMode == SellMode.Auction) {
            require(_startPrice > 0, "Invalid auction start price");
        } else if (_sellMode == SellMode.DutchAuction) {
            uint256 discount = (_discountAmount * _duration) / _discountInterval;
            require(_startPrice > discount, "Start price lower than total discount");
        }

        _depositNft(msg.sender, _hostContract, _tokenId);

        bytes32 listingId = keccak256(abi.encodePacked(operationNonce, _hostContract, _tokenId));

        listingRegistry[listingId].id = listingId;
        listingRegistry[listingId].seller = msg.sender;
        listingRegistry[listingId].hostContract = _hostContract;
        listingRegistry[listingId].tokenId = _tokenId;
        listingRegistry[listingId].sellMode = _sellMode;
        listingRegistry[listingId].startPrice = _startPrice;
        listingRegistry[listingId].buyNowPrice = _buyNowPrice;
        listingRegistry[listingId].startTime = _startTime;
        listingRegistry[listingId].auctionDuration = _duration;
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
            _startPrice,
            _buyNowPrice,
            _startTime,
            _duration,
            _discountInterval,
            _discountAmount
        );
    }

    function listingOfAddr(address addr) public view returns (bytes32[] memory) {
        return addrListingIds[addr];
    }

    function getPrice(bytes32 listingId) public view returns (uint256) {
        listing storage lst = listingRegistry[listingId];
        require(lst.startTime > 0, "The listing doesn't exist");

        if (lst.sellMode == SellMode.DutchAuction) {
            uint256 timeElapsed = block.timestamp - lst.startTime;
            uint256 discount = lst.discountAmount * (timeElapsed / lst.discountInterval);
            return lst.startPrice - discount;
        }

        return lst.buyNowPrice;
    }

    /*
     * @notice Place bidding for the listing item, only support normal auction.
     * @dev The bidding price must higher than previous price.
     */
    function placeBid(bytes32 listingId, uint256 price) external nonReentrant {
        listing storage lst = listingRegistry[listingId];
        require(lst.sellMode == SellMode.Auction, "Can only bid for listing on auction");
        require(block.timestamp >= lst.startTime, "The auction haven't start");
        require(
            lst.startTime + lst.auctionDuration >= block.timestamp,
            "The auction already expired"
        );
        require(msg.sender != lst.seller, "Bidder cannot be seller");

        uint256 minPrice = lst.startPrice;
        // The last element is the current highest price
        if (lst.biddingIds.length > 0) {
            bytes32 lastBiddingId = lst.biddingIds[lst.biddingIds.length - 1];
            minPrice = biddingRegistry[lastBiddingId].price;
        }

        require(price > minPrice, "Bid price too low");

        _depositToken(msg.sender, price);

        bytes32 biddingId = keccak256(
            abi.encodePacked(operationNonce, lst.hostContract, lst.tokenId)
        );
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

    function biddingOfAddr(address addr) public view returns (bytes32[] memory) {
        return addrBiddingIds[addr];
    }

    /*
     * @notice Immediately buy the NFT.
     * @dev If it is dutch auction, then the price is dutch auction price, if normal auction, then the price is buyNowPrice.
     */
    function buyNow(bytes32 listingId) external nonReentrant {
        listing storage lst = listingRegistry[listingId];
        require(lst.sellMode != SellMode.Auction, "Auction not support buy now");
        require(block.timestamp >= lst.startTime, "The auction haven't start");
        require(
            lst.startTime + lst.auctionDuration >= block.timestamp,
            "The auction already expired"
        );
        require(msg.sender != lst.seller, "Buyer cannot be seller");

        uint256 price = getPrice(listingId);

        _processFee(msg.sender, price);

        // Deposit the tokens to market place contract.
        _depositToken(msg.sender, price);

        uint256 sellerAmount = price;
        if (_checkRoyalties(lst.hostContract)) {
            sellerAmount = _deduceRoyalties(lst.hostContract, lst.tokenId, price);
        }

        _transferToken(msg.sender, lst.seller, sellerAmount);
        _transferNft(msg.sender, lst.hostContract, lst.tokenId);

        if (lst.hostContract == fireNftContractAddress) {
            _burnTokenOnFireNft(price);
        }

        emit BuyNow(listingId, msg.sender, price);

        _removeListing(listingId, lst.seller);
    }

    function _removeListing(bytes32 listingId, address seller) private {
        uint256 length = addrListingIds[seller].length;
        for (uint256 index = 0; index < length; ++index) {
            // Move the last element to the index need to remove
            if (addrListingIds[seller][index] == listingId && index != length - 1) {
                addrListingIds[seller][index] = addrListingIds[seller][length - 1];
            }
        }
        // Remove the last element
        addrListingIds[seller].pop();

        // Delete from the mapping
        delete listingRegistry[listingId];

        emit ListingRemoved(listingId, seller);
    }

    /*
     * @notice The highest bidder claim the NFT he bought.
     * @dev Can only claim after the auction period finished.
     */
    function claimNft(bytes32 biddingId) external nonReentrant {
        bidding storage bid = biddingRegistry[biddingId];
        require(bid.bidder == msg.sender, "Only bidder can claim NFT");

        listing storage lst = listingRegistry[bid.listingId];
        require(
            lst.startTime + lst.auctionDuration < block.timestamp,
            "The bidding period haven't complete"
        );
        for (uint256 i = 0; i < lst.biddingIds.length; ++i) {
            bytes32 tmpId = lst.biddingIds[i];
            if (biddingRegistry[tmpId].price > bid.price) {
                require(false, "The bidding is not the highest price");
            }
        }

        _processFee(msg.sender, bid.price);
        _transferNft(msg.sender, lst.hostContract, lst.tokenId);

        uint256 sellerAmount = bid.price;
        if (_checkRoyalties(lst.hostContract)) {
            sellerAmount = _deduceRoyalties(lst.hostContract, lst.tokenId, bid.price);
        }

        _transferToken(msg.sender, lst.seller, sellerAmount);

        if (lst.hostContract == fireNftContractAddress) {
            _burnTokenOnFireNft(bid.price);
        }

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
    }

    function removeListing(bytes32 listingId) external nonReentrant {
        listing storage lst = listingRegistry[listingId];
        require(
            lst.startTime + lst.auctionDuration < block.timestamp,
            "The listing haven't expired"
        );
        require(lst.seller == msg.sender, "Only seller can remove");
        require(lst.biddingIds.length == 0, "Already received bidding, cannot close");

        // return the NFT to seller
        _transferNft(msg.sender, lst.hostContract, lst.tokenId);

        _removeListing(lst.id, lst.seller);
    }

    function _processFee(address buyer, uint256 price) internal {
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        uint256 feeToBurn = (fee * feeBurnRate) / FEE_RATE_BASE;
        uint256 revenue = fee - feeToBurn;
        lfgToken.transferFrom(buyer, revenueAddress, revenue);
        lfgToken.transferFrom(buyer, burnAddress, feeToBurn);
        totalBurnAmount += feeToBurn;

        revenueAmount += revenue;
    }

    function _depositNft(
        address from,
        address _hostContract,
        uint256 _tokenId
    ) internal {
        ERC721 nftContract = ERC721(_hostContract);
        nftContract.safeTransferFrom(from, address(this), _tokenId);

        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));
        nftItems[itemId] = nftItem({owner: from, hostContract: _hostContract, tokenId: _tokenId});

        emit NftDeposit(from, _hostContract, _tokenId);
    }

    function _transferNft(
        address to,
        address _hostContract,
        uint256 _tokenId
    ) internal {
        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));

        ERC721 nftContract = ERC721(_hostContract);
        nftContract.safeTransferFrom(address(this), to, _tokenId);
        delete nftItems[itemId];

        emit NftTransfer(to, _hostContract, _tokenId);
    }

    function _depositToken(address addr, uint256 _amount) internal {
        lfgToken.transferFrom(addr, address(this), _amount);
        addrTokens[addr].lockedAmount += _amount;
        totalEscrowAmount += _amount;
    }

    function _transferToken(
        address from,
        address to,
        uint256 _amount
    ) internal {
        require(addrTokens[from].lockedAmount >= _amount, "The locked amount is not enough");
        lfgToken.transfer(to, _amount);
        addrTokens[from].lockedAmount -= _amount;
        totalEscrowAmount -= _amount;
    }

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /*
     * @notice Set the burn and revenue address, combine into one function to reduece contract size.
     * @dev Only callable by owner.
     * @param _burnAddress: the burn address
     * @param _revenueAddress: the revenue address
     */
    function setBurnAndRevenueAddress(address _burnAddress, address _revenueAddress)
        external
        onlyOwner
    {
        require(_revenueAddress != address(0), "Invalid revenue address");

        burnAddress = _burnAddress;
        revenueAddress = _revenueAddress;
    }

    function setFireNftContractInfo(address _address, IBurnToken _burnTokenContract)
        external
        onlyOwner
    {
        require(_address != address(0), "Invalid address");
        fireNftContractAddress = _address;
        burnTokenContract = _burnTokenContract;
    }

    function _burnTokenOnFireNft(uint256 price) internal {
        burnTokenContract.burn(price);
    }

    function setNftWhiteListContract(INftWhiteList _whitelistContract)
        external
        onlyOwner
    {
        nftWhiteListContract = _whitelistContract;
    }
}
