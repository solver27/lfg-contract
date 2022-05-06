// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SAMLazyMintBase.sol";

contract SAMLazyMintGas is SAMLazyMintBase {
    constructor(
        address _owner,
        LFGNFT1155 _nftContract,
        ISAMConfig _samConfig
    ) SAMLazyMintBase(_owner, _nftContract, _samConfig) {}

    /*
     * @notice Immediately buy the NFT.
     * @dev If it is dutch auction, then the price is dutch auction price, if normal auction, then the price is buyNowPrice.
     */
    function buyNow(bytes32 listingId) external payable nonReentrant {
        _buyNow(listingId);
    }

    /*
     * @notice Place bidding for the listing item, only support normal auction.
     * @dev The bidding price must higher than previous price.
     */
    function placeBid(bytes32 listingId, uint256 price) external payable nonReentrant {
        _placeBid(listingId, price);
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

        _claimNft(biddingId);
    }

       /// Check base function definition
    function _processFee(uint256 price) internal override {
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        payable(samConfig.getRevenueAddress()).transfer(fee);
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

}