// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Contract trade using GAS(ETH, BNB)*/
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "./interfaces/IERC2981.sol";
import "./SAMContractBase.sol";

contract SAMContractGas is SAMContractBase {
    constructor(
        address _owner,
        INftWhiteList _nftWhiteList,
        address _revenueAddress
    ) SAMContractBase(_owner, _nftWhiteList, _revenueAddress) {
    }

    /*
     * @notice Place bidding for the listing item, only support normal auction.
     * @dev The bidding price must higher than previous price.
     */
    function placeBid(bytes32 listingId) external payable nonReentrant {
        _placeBid(listingId, msg.value);
    }

    /*
     * @notice Add NFT to marketplace, Support auction(Price increasing), buyNow (Fixed price) and dutch auction (Price decreasing).
     * @dev Only the token owner can call, because need to transfer the ownership to marketplace contract.
     */
    function addListing(
        address _hostContract,
        uint256 _tokenId,
        uint256 _copies,
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
            _copies,
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
        uint256 price = getPrice(listingId);
        // For BNB, the value need to larger then the price + fee
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        require(msg.value >= price + fee, "Not enough funds to buy");

        _buyNow(listingId, price);
    }

    /// Check base function definition
    function _processFee(uint256 price) internal override {
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        payable(revenueAddress).transfer(fee);
        revenueAmount += fee;
    }

    // Escrow the gas to the contract, using _amount instead of msg.value
    // because msg.value may include the fee.
    function _depositToken(uint256 _amount) internal override {
        addrTokens[msg.sender] += _amount;
        totalEscrowAmount += _amount;
    }

    /// Check base function definition
    function _transferToken(
        address from,
        address to,
        uint256 _amount
    ) internal override {
        require(addrTokens[from] >= _amount, "The locked amount is not enough");
        payable(to).transfer(_amount);
        addrTokens[from] -= _amount;
        totalEscrowAmount -= _amount;
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

        _claimNft(biddingId, bid, lst);
    }

    
}
