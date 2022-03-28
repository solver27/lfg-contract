// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Contract trade using GAS(ETH, BNB)*/
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "./interfaces/IERC2981.sol";
import "./SAMContractBase.sol";

contract SAMContractGas is SAMContractBase {
    event ClaimBalance(address indexed addr, uint256 amount);

    // Total revenue amount
    uint256 public revenueAmount;

    struct userToken {
        uint256 claimableAmount;
        uint256 lockedAmount;
    }

    mapping(address => userToken) public addrTokens;

    constructor(address _owner, INftWhiteList _nftWhiteList) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);
        nftWhiteListContract = _nftWhiteList;

        feeRate = 250; // 2.5%
        royaltiesFeeRate = 1000; // Default 10% royalties fee.
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
                revenueAmount += royaltyFee;

                emit RoyaltiesFeePaid(_contract, tokenId, royaltyFee);
            }

            uint256 payToReceiver = royaltiesAmount - royaltyFee;
            addrTokens[royaltiesReceiver].claimableAmount = payToReceiver;

            // Broadcast royalties payment
            emit RoyaltiesPaid(_contract, tokenId, payToReceiver);
        }

        return netSaleValue;
    }

    /*
     * @notice Place bidding for the listing item, only support normal auction.
     * @dev The bidding price must higher than previous price.
     */
    function placeBid(bytes32 listingId) external payable nonReentrant {
        listing storage lst = listingRegistry[listingId];
        require(lst.sellMode == SellMode.Auction, "Can only bid for listing on auction");
        require(block.timestamp >= lst.startTime, "The auction haven't start");
        require(
            lst.startTime + lst.duration >= block.timestamp,
            "The auction already expired"
        );
        require(msg.sender != lst.seller, "Bidder cannot be seller");

        uint256 minPrice = lst.price;
        // The last element is the current highest price
        if (lst.biddingIds.length > 0) {
            bytes32 lastBiddingId = lst.biddingIds[lst.biddingIds.length - 1];
            minPrice = biddingRegistry[lastBiddingId].price;
        }

        require(msg.value > minPrice, "Bid price too low");

        addrTokens[msg.sender].lockedAmount += msg.value;
        totalEscrowAmount += msg.value;

        bytes32 biddingId = keccak256(
            abi.encodePacked(operationNonce, lst.hostContract, lst.tokenId)
        );
        biddingRegistry[biddingId].id = biddingId;
        biddingRegistry[biddingId].bidder = msg.sender;
        biddingRegistry[biddingId].listingId = listingId;
        biddingRegistry[biddingId].price = msg.value;
        biddingRegistry[biddingId].timestamp = block.timestamp;

        operationNonce++;

        lst.biddingIds.push(biddingId);

        addrBiddingIds[msg.sender].push(biddingId);

        emit BiddingPlaced(biddingId, listingId, msg.value);
    }

    /*
     * @notice Add NFT to marketplace, Support auction(Price increasing), buyNow (Fixed price) and dutch auction (Price decreasing).
     * @dev Only the token owner can call, because need to transfer the ownership to marketplace contract.
     */
    function addListing(
        address _hostContract,
        uint256 _tokenId,
        SellMode _sellMode,
        uint256 _price,
        uint256 _startTime,
        uint256 _duration,
        uint256 _discountInterval,
        uint256 _discountAmount
    ) external nonReentrant {
        require(_hostContract != fireNftContractAddress, "FireNFT can only sell for LFG");
        _addListing(
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

    /*
     * @notice Immediately buy the NFT.
     * @dev If it is dutch auction, then the price is dutch auction price, if normal auction, then the price is buyNowPrice.
     */
    function buyNow(bytes32 listingId) external payable nonReentrant {
        listing storage lst = listingRegistry[listingId];
        require(lst.sellMode != SellMode.Auction, "Auction not support buy now");
        require(block.timestamp >= lst.startTime, "The auction haven't start");
        require(
            lst.startTime + lst.duration >= block.timestamp,
            "The auction already expired"
        );
        require(msg.sender != lst.seller, "Buyer cannot be seller");

        uint256 price = getPrice(listingId);

        // For BNB, the value need to larger then the price + fee
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        require(msg.value >= price + fee, "Not enough funds to buy");

        totalEscrowAmount += price;

        uint256 sellerAmount = price;
        if (_checkRoyalties(lst.hostContract)) {
            sellerAmount = _deduceRoyalties(lst.hostContract, lst.tokenId, price);
        }

        addrTokens[lst.seller].claimableAmount += sellerAmount;
        revenueAmount += msg.value - price;
        _transferNft(listingId, msg.sender, lst.hostContract, lst.tokenId);

        emit BuyNow(listingId, msg.sender, price);

        _removeListing(listingId, lst.seller);
    }

    /*
     * @notice The highest bidder claim the NFT he bought. The bidder need to pay 2.5% of bidding price for the fee.
     * @dev Can only claim after the auction period finished.
     */
    function claimNft(bytes32 biddingId) external payable nonReentrant {
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

        uint256 fee = (bid.price * feeRate) / FEE_RATE_BASE;
        require(msg.value >= fee, "Not enough gas to pay the fee");
        revenueAmount += msg.value;

        _transferNft(lst.id, msg.sender, lst.hostContract, lst.tokenId);

        uint256 sellerAmount = bid.price;
        if (_checkRoyalties(lst.hostContract)) {
            sellerAmount = _deduceRoyalties(lst.hostContract, lst.tokenId, bid.price);
        }

        addrTokens[msg.sender].lockedAmount -= bid.price;
        addrTokens[lst.seller].claimableAmount += sellerAmount;

        emit ClaimNFT(lst.id, biddingId, msg.sender);

        // Refund the failed bidder
        for (uint256 i = 0; i < lst.biddingIds.length; ++i) {
            bytes32 tmpId = lst.biddingIds[i];
            if (tmpId != biddingId) {
                addrTokens[biddingRegistry[tmpId].bidder].lockedAmount -= biddingRegistry[tmpId]
                    .price;
                addrTokens[biddingRegistry[tmpId].bidder].claimableAmount += biddingRegistry[tmpId]
                    .price;
            }
        }

        _removeListing(lst.id, lst.seller);
    }

    /*
     * @notice The NFT seller or failed bidder can claim the token back.
     * @dev All the available token under his account will be claimed.
     */
    function claimBalance() external nonReentrant {
        require(addrTokens[msg.sender].claimableAmount > 0, "The claimableAmount is zero");
        payable(msg.sender).transfer(addrTokens[msg.sender].claimableAmount);

        emit ClaimBalance(msg.sender, addrTokens[msg.sender].claimableAmount);

        totalEscrowAmount -= addrTokens[msg.sender].claimableAmount;
        addrTokens[msg.sender].claimableAmount = 0;
    }

    /*
     * @notice Owner to withdraw revenue from the contract.
     */
    function revenueSweep() external onlyOwner {
        require(revenueAmount > 0, "No revenue to sweep");
        payable(msg.sender).transfer(revenueAmount);
        revenueAmount = 0;
    }
}
