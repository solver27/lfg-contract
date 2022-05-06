// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Contract trade by ERC20 token(LFG, USDT) */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */
//** The difference with SAMContract is it doesn't charge royalties, and doesn't */
//** burn token when the FireNFT is sold because all the FireNFT is mintted      */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./SAMLazyMintBase.sol";

contract SAMLazyMint is SAMLazyMintBase {
    uint256 public constant MAXIMUM_FEE_BURN_RATE = 10000; // maximum burn 100% of the fee

    // The total burned token amount
    uint256 public totalBurnAmount;

    IERC20 public lfgToken;

    constructor(
        address _owner,
        IERC20 _lfgToken,
        LFGNFT1155 _nftContract,
        ISAMConfig _samConfig
    ) SAMLazyMintBase(_owner, _nftContract, _samConfig) {
        lfgToken = _lfgToken;
        feeRate = 125; // 1.25%
    }

    /*
     * @notice Immediately buy the NFT.
     * @dev If it is dutch auction, then the price is dutch auction price, if normal auction, then the price is buyNowPrice.
     */
    function buyNow(bytes32 listingId) external nonReentrant {
        _buyNow(listingId);
    }

    /*
     * @notice Place bidding for the listing item, only support normal auction.
     * @dev The bidding price must higher than previous price.
     */
    function placeBid(bytes32 listingId, uint256 price) external nonReentrant {
        _placeBid(listingId, price);
    }

    /*
     * @notice The highest bidder claim the NFT he bought.
     * @dev Can only claim after the auction period finished.
     */
    function claimNft(bytes32 biddingId) external nonReentrant {
        _claimNft(biddingId);
    }

    function _processFee(uint256 price) internal override {
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        uint256 feeToBurn = (fee * samConfig.getFeeBurnRate()) / FEE_RATE_BASE;
        uint256 revenue = fee - feeToBurn;
        SafeERC20.safeTransferFrom(lfgToken, msg.sender, samConfig.getRevenueAddress(), revenue);
        revenueAmount += revenue;

        SafeERC20.safeTransferFrom(lfgToken, msg.sender, samConfig.getBurnAddress(), feeToBurn);
        totalBurnAmount += feeToBurn;
    }

    function _depositToken(uint256 _amount) internal override {
        // Using lfgToken.safeTransferFrom(addr, address(this), _amount) will increase
        // contract size for 0.13KB, which will make the contract no deployable.
        SafeERC20.safeTransferFrom(lfgToken, msg.sender, address(this), _amount);
        addrTokens[msg.sender] += _amount;
        totalEscrowAmount += _amount;
    }

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
}
