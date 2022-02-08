// SPDX-License-Identifier: MIT

//** LFG Vesting Contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NftEscrow is Ownable, ReentrancyGuard, IERC721Receiver {

    event NftDeposit(address indexed sender, address indexed hostContract, uint tokenId);

    event NftWithdraw(address indexed sender, address indexed hostContract, uint tokenId);

    struct nftItem {
        address owner;          // The owner of the NFT
        address hostContract;   // The source of the contract
        uint tokenId;           // The NFT token ID
    }

    mapping (bytes32 => nftItem) public nftItems;

    struct userToken {
        uint256 lockedAmount;
        uint256 claimableAmount;
    }

    mapping (address => userToken) public addrTokens;

    uint256 public totalEscrowAmount;

    IERC20 public lfgToken;

    address public operator;

    constructor (address _owner, IERC20 _lfgToken) {
        _transferOwnership(_owner);
        lfgToken = _lfgToken;
    }

    function setOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "Only operator can do this operation");
        _;
    }

    function depositNft(address from, address _hostContract, uint _tokenId) external nonReentrant onlyOperator {
        ERC721 nftContract = ERC721(_hostContract);
        nftContract.safeTransferFrom(from, address(this), _tokenId);

        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));
        nftItems[itemId] = nftItem({owner: from, hostContract : _hostContract, tokenId : _tokenId });

        emit NftDeposit(from, _hostContract, _tokenId);
    }

    function withdrawNft(address to, address _hostContract, uint _tokenId) external nonReentrant onlyOperator {
        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));
        require(nftItems[itemId].owner == to, "The NFT item doesn't belong to the caller");

        ERC721 nftContract = ERC721(_hostContract);
        nftContract.safeTransferFrom(address(this), to, _tokenId);
        delete nftItems[itemId];

        emit NftWithdraw(to, _hostContract, _tokenId);
    }

    function transferNft(address to, address _hostContract, uint _tokenId) external nonReentrant onlyOperator {
        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));

        ERC721 nftContract = ERC721(_hostContract);
        nftContract.safeTransferFrom(address(this), to, _tokenId);
        delete nftItems[itemId];
    }

    function depositToken(address addr, uint256 _amount) external nonReentrant onlyOperator {
        lfgToken.transferFrom(addr, address(this), _amount);
        addrTokens[addr].lockedAmount += _amount;
        totalEscrowAmount += _amount;
    }

    function claimToken(address addr) external nonReentrant onlyOperator returns (uint256) {
        require(addrTokens[addr].claimableAmount > 0);
        lfgToken.transfer(addr, addrTokens[addr].claimableAmount);
        uint256 claimedAmount = addrTokens[addr].claimableAmount;
        totalEscrowAmount -= addrTokens[addr].claimableAmount;
        addrTokens[addr].claimableAmount = 0;

        return claimedAmount;
    }

    function transferToken(address from, address to, uint256 _amount) external nonReentrant onlyOperator {
        require(addrTokens[from].lockedAmount >= _amount, "The locked amount is not enough");
        addrTokens[to].claimableAmount += _amount;
        addrTokens[from].lockedAmount -= _amount;
    }

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
