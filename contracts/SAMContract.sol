// SPDX-License-Identifier: MIT

//** SAM(Social Aggregator Marketplace) Contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBurnToken.sol";
import "./interfaces/IERC2981.sol";
import "./SAMContractBase.sol";

contract SAMContract is SAMContractBase {
    uint256 public constant MAXIMUM_FEE_BURN_RATE = 10000; // maximum burn 100% of the fee

    // The rate of fee to burn
    uint256 public feeBurnRate;

    // The address to burn token
    address public burnAddress;

    uint256 public totalBurnAmount;

    // The revenue address
    address public revenueAddress;

    // Total revenue amount
    uint256 public revenueAmount;

    //address public burnFromAddress;
    IBurnToken public burnTokenContract;

    IERC20 public lfgToken;

    mapping(address => uint256) public addrTokens;

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
     * @notice Update the burn fee rate from the burn amount
     * @dev Only callable by owner.
     * @param _fee: the fee rate
     * @param _burnRate: the burn fee rate
     */
    function updateBurnFeeRate(uint256 _feeBurnRate) external onlyOwner {
        require(_feeBurnRate <= FEE_RATE_BASE, "Invalid fee burn rate");
        feeBurnRate = _feeBurnRate;
    }

    /*
     * @notice Place bidding for the listing item, only support normal auction.
     * @dev The bidding price must higher than previous price.
     */
    function placeBid(bytes32 listingId, uint256 price) external nonReentrant {
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
    function buyNow(bytes32 listingId) external nonReentrant {
        listing storage lst = listingRegistry[listingId];
        require(lst.sellMode != SellMode.Auction, "Auction not support buy now");
        require(block.timestamp >= lst.startTime, "The auction haven't start");
        require(lst.startTime + lst.duration >= block.timestamp, "The auction already expired");
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
        _transferNft(listingId, msg.sender, lst.hostContract, lst.tokenId);

        if (lst.hostContract == fireNftContractAddress) {
            _burnTokenOnFireNft(price);
        }

        emit BuyNow(listingId, msg.sender, price);

        _removeListing(listingId, lst.seller);
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
        for (uint256 i = 0; i < lst.biddingIds.length; ++i) {
            bytes32 tmpId = lst.biddingIds[i];
            if (biddingRegistry[tmpId].price > bid.price) {
                require(false, "The bidding is not the highest price");
            }
        }

        _processFee(msg.sender, bid.price);
        _transferNft(lst.id, msg.sender, lst.hostContract, lst.tokenId);

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

    function _processFee(address buyer, uint256 price) internal {
        uint256 fee = (price * feeRate) / FEE_RATE_BASE;
        uint256 feeToBurn = (fee * feeBurnRate) / FEE_RATE_BASE;
        uint256 revenue = fee - feeToBurn;
        SafeERC20.safeTransferFrom(lfgToken, buyer, revenueAddress, revenue);
        revenueAmount += revenue;

        SafeERC20.safeTransferFrom(lfgToken,buyer, burnAddress, feeToBurn);
        totalBurnAmount += feeToBurn;
    }

    function _depositToken(address addr, uint256 _amount) internal {
        // Using lfgToken.safeTransferFrom(addr, address(this), _amount) will increase
        // contract size for 0.13KB, which will make the contract no deployable.
        SafeERC20.safeTransferFrom(lfgToken, addr, address(this), _amount);
        addrTokens[addr] += _amount;
        totalEscrowAmount += _amount;
    }

    function _transferToken(
        address from,
        address to,
        uint256 _amount
    ) internal {
        require(addrTokens[from] >= _amount, "The locked amount is not enough");
        SafeERC20.safeTransfer(lfgToken, to, _amount);
        addrTokens[from] -= _amount;
        totalEscrowAmount -= _amount;
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

    function setBurnTokenContract(IBurnToken _burnTokenContract) external onlyOwner {
        burnTokenContract = _burnTokenContract;
    }

    function _burnTokenOnFireNft(uint256 price) internal {
        burnTokenContract.burn(price);
    }
}
