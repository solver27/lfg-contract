// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Contract trade using GAS(ETH, BNB)*/
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "./interfaces/IERC2981.sol";
import "./SAMContractBase.sol";
import "hardhat/console.sol";

contract SAMContractGas is SAMContractBase {
    constructor(
        address _owner,
        INftWhiteList _nftWhiteList,
        address _revenueAddress
    ) SAMContractBase(_owner, _nftWhiteList, _revenueAddress) {
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
     * @notice Place bidding for the listing item, only support normal auction.
     * @dev The bidding price must higher than previous price.
     */
    function placeBid(bytes32 listingId) external payable nonReentrant {
        listing storage lst = listingRegistry[listingId];
        require(lst.sellMode == SellMode.Auction, "Can only bid for listing on auction");
        require(block.timestamp >= lst.startTime, "The auction haven't start");
        require(lst.startTime + lst.duration >= block.timestamp, "The auction already expired");
        require(msg.sender != lst.seller, "Bidder cannot be seller");

        uint256 minPrice = lst.price;

        if (lst.biddingId != 0) {
            minPrice = biddingRegistry[lst.biddingId].price;
        }

        require(msg.value > minPrice, "Bid price too low");

        if (lst.biddingId != 0) {
            address olderBidder = biddingRegistry[lst.biddingId].bidder;
            console.log(
                "Refund %s tokens to %s",
                biddingRegistry[lst.biddingId].price,
                olderBidder
            );
            _transferToken(olderBidder, olderBidder, biddingRegistry[lst.biddingId].price);
            _removeBidding(lst.biddingId, olderBidder);
        }

        _depositToken(msg.value);

        bytes32 biddingId = keccak256(
            abi.encodePacked(operationNonce, lst.hostContract, lst.tokenId)
        );

        biddingRegistry[biddingId].bidder = msg.sender;
        biddingRegistry[biddingId].listingId = listingId;
        biddingRegistry[biddingId].price = msg.value;
        biddingRegistry[biddingId].timestamp = block.timestamp;

        operationNonce++;

        lst.biddingId = biddingId;

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
        // Only check for dutch auction, for fixed price there is no duration
        if (lst.sellMode == SellMode.DutchAuction) {
            require(block.timestamp >= lst.startTime, "The auction haven't start");
            require(lst.startTime + lst.duration >= block.timestamp, "The auction already expired");
        }
        require(msg.sender != lst.seller, "Buyer cannot be seller");

        uint256 price = getPrice(listingId);

        // For BNB, the value need to larger then the price + fee
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        require(msg.value >= price + fee, "Not enough funds to buy");

        _processFee(price);

        _depositToken(price);

        uint256 sellerAmount = price;
        if (_checkRoyalties(lst.hostContract)) {
            sellerAmount = _deduceRoyalties(lst.hostContract, lst.tokenId, price);
        }

        _transferToken(msg.sender, lst.seller, sellerAmount);

        _transferNft(msg.sender, lst.hostContract, lst.tokenId);

        emit BuyNow(listingId, msg.sender, price);

        _removeListing(listingId, lst.seller);
    }

    function _processFee(uint256 price) internal {
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        payable(revenueAddress).transfer(fee);
        revenueAmount += fee;
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

        uint256 fee = (bid.price * feeRate) / FEE_RATE_BASE;
        require(msg.value >= fee, "Not enough gas to pay the fee");

        _processFee(bid.price);
        _transferNft(msg.sender, lst.hostContract, lst.tokenId);

        uint256 sellerAmount = bid.price;
        if (_checkRoyalties(lst.hostContract)) {
            sellerAmount = _deduceRoyalties(lst.hostContract, lst.tokenId, bid.price);
        }

        _transferToken(msg.sender, lst.seller, sellerAmount);

        emit ClaimNFT(bid.listingId, biddingId, msg.sender);

        _removeListing(bid.listingId, lst.seller);
    }

    // Escrow the gas to the contract, using _amount instead of msg.value
    // because msg.value may include the fee.
    function _depositToken(uint256 _amount) internal {
        // Using lfgToken.safeTransferFrom(addr, address(this), _amount) will increase
        // contract size for 0.13KB, which will make the contract no deployable.
        addrTokens[msg.sender] += _amount;
        totalEscrowAmount += _amount;
    }

    function _transferToken(
        address from,
        address to,
        uint256 _amount
    ) internal {
        require(addrTokens[from] >= _amount, "The locked amount is not enough");
        payable(to).transfer(_amount);
        addrTokens[from] -= _amount;
        totalEscrowAmount -= _amount;
    }
}
