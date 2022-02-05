// SPDX-License-Identifier: MIT

//** LFG Vesting Contract */
//** Author Xiao Shengguang : SAM(Social Aggregator Marketplace) Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NftEscrow is Ownable, ReentrancyGuard {

    event NftDeposit(address indexed sender, address indexed hostContract, uint tokenId);

    event NftWithdraw(address indexed sender, address indexed hostContract, uint tokenId);

    struct nftItem {
        address owner;          // The owner of the NFT
        address hostContract;   // The source of the contract
        uint tokenId;           // The NFT token ID
    }

    mapping (bytes32 => nftItem) nftItems;

    mapping (address => uint256) addrTokens;

    uint256 public totalEscrowAmount;

    IERC20 public lfgToken;

    address public operator;

    constructor (address _owner, IERC20 _token) {
        _transferOwnership(_owner);
        lfgToken = _token;
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
        nftContract.transferFrom(from, address(this), _tokenId);

        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));
        nftItems[itemId] = nftItem({owner: from, hostContract : _hostContract, tokenId : _tokenId });

        emit NftDeposit(from, _hostContract, _tokenId);
    }

    function withdrawNft(address to, address _hostContract, uint _tokenId) external nonReentrant onlyOperator {
        bytes32 itemId = keccak256(abi.encodePacked(_hostContract, _tokenId));
        require(nftItems[itemId].owner == to, "The NFT item doesn't belong to the caller");

        ERC721 nftContract = ERC721(_hostContract);
        nftContract.transferFrom(address(this), to, _tokenId);
        delete nftItems[itemId];

        emit NftWithdraw(to, _hostContract, _tokenId);
    }

    function depositToken(address addr, uint256 _amount) external nonReentrant onlyOperator {
        lfgToken.transferFrom(addr, address(this), _amount);
        addrTokens[addr] += _amount;
        totalEscrowAmount += _amount;
    }

    function withdrawToken(address addr, uint256 _amount) external nonReentrant onlyOperator {
        require(addrTokens[addr] >= _amount);
        lfgToken.transfer(addr, _amount);
        totalEscrowAmount -= _amount;
    }
}
