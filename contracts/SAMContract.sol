// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Contract trade by ERC20 token(LFG, USDT) */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBurnToken.sol";
import "./interfaces/IERC2981.sol";
import "./SAMContractBase.sol";

contract SAMContract is SAMContractBase {
    uint256 public constant MAXIMUM_FEE_BURN_RATE = 10000; // maximum burn 100% of the fee

    // The rate of fee to burn
    // uint256 public feeBurnRate;

    // The address to burn token
    // address public burnAddress;

    // The total burned token amount
    uint256 public totalBurnAmount;

    //address public burnFromAddress;
    IBurnToken public burnTokenContract;

    IERC20 public lfgToken;

    constructor(
        address _owner,
        IERC20 _lfgToken,
        INftWhiteList _nftWhiteList,
        ISAMConfig _samConfig
    ) SAMContractBase(_owner, _nftWhiteList) {
        lfgToken = _lfgToken;

        feeRate = 125; // 1.25%
        samConfig = _samConfig;
    }

    /*
     * @notice Update the burn fee rate from the burn amount
     * @dev Only callable by owner.
     * @param _fee: the fee rate
     * @param _burnRate: the burn fee rate
     */
    // function updateBurnFeeRate(uint256 _feeBurnRate) external onlyOwner {
    //     require(_feeBurnRate <= FEE_RATE_BASE, "Invalid fee burn rate");
    //     feeBurnRate = _feeBurnRate;
    // }

    /*
     * @notice Place bidding for the listing item, only support normal auction.
     * @dev The bidding price must higher than previous price.
     */
    function placeBid(bytes32 listingId, uint256 price) external nonReentrant {
        _placeBid(listingId, price);
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
    function buyNow(bytes32 listingId) external nonReentrant {
        uint256 price = getPrice(listingId);
        address hostContract = _buyNow(listingId, price);

        if (hostContract == samConfig.getFireNftAddress()) {
            burnTokenContract.burn(price);
        }
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
            lst.startTime + lst.duration < block.timestamp,
            "The bidding period haven't complete"
        );

        // Use the bid.price before _claimNft, because the bid will be deleted in _claimNft.
        if (lst.hostContract == samConfig.getFireNftAddress()) {
            burnTokenContract.burn(bid.price);
        }

        _claimNft(biddingId, bid, lst);
    }

    /// Check base function definition
    function _processFee(uint256 price) internal override {
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        uint256 feeToBurn = (fee * samConfig.getFeeBurnRate()) / FEE_RATE_BASE;
        uint256 revenue = fee - feeToBurn;
        SafeERC20.safeTransferFrom(lfgToken, msg.sender, samConfig.getRevenueAddress(), revenue);
        revenueAmount += revenue;

        SafeERC20.safeTransferFrom(lfgToken, msg.sender, samConfig.getBurnAddress(), feeToBurn);
        totalBurnAmount += feeToBurn;
    }

    /// Check base function definition
    function _depositToken(uint256 _amount) internal override {
        // Using lfgToken.safeTransferFrom(addr, address(this), _amount) will increase
        // contract size for 0.13KB, which will make the contract no deployable.
        SafeERC20.safeTransferFrom(lfgToken, msg.sender, address(this), _amount);
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
        SafeERC20.safeTransfer(lfgToken, to, _amount);
        addrTokens[from] -= _amount;
        totalEscrowAmount -= _amount;
    }

    /*
     * @notice Set the burn address, only applicable for this contract which use LFG token.
     * @dev Only callable by owner.
     * @param _burnAddress: the burn token address
     */
    // function setBurnAddress(address _burnAddress) external onlyOwner {
    //     burnAddress = _burnAddress;
    // }

    function setBurnTokenContract(IBurnToken _burnTokenContract) external onlyOwner {
        burnTokenContract = _burnTokenContract;
    }
}
