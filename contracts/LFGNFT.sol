//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./interfaces/ILFGNFT.sol";

contract LFGNFT is ILFGNFT, ERC721Enumerable, IERC2981, Ownable {
    using Strings for uint256;

    // Base Token URI
    string public baseURI;

    // MAX supply of collection
    uint256 public maxSupply;

    // Max batch quantity limit
    uint256 public constant MAX_BATCH_QUANTITY = 1000;

    // Max quantity can mint each time
    uint256 public maxBatchQuantity;

    // creators
    mapping(uint256 => address) public creators;

    struct RoyaltyInfo {
        address receiver;   // The payment receiver of royalty
        uint16 rate;        // The rate of the payment
    }

    // royalties
    mapping(uint256 => RoyaltyInfo) private royalties;

    // MAX royalty percent
    uint16 public constant MAX_ROYALTY = 5000;

    constructor() ERC721("LFGNFT", "LFGNFT") {
        maxSupply = 10000;
        maxBatchQuantity = 10;
    }

    /**************************
     ***** MINT FUNCTIONS *****
     *************************/
    function mint(uint256 _qty, address _to) external {
        require(totalSupply() + _qty <= maxSupply, "NFT: out of stock");
        require(_to != address(0), "NFT: invalid address");
        require(_qty <= maxBatchQuantity, "NFT: cannot mint over max batch quantity");

        for (uint256 i = 0; i < _qty; i++) {
            // Using tokenId in the loop instead of totalSupply() + 1,
            // because totalSupply() changed after _safeMint function call.
            uint256 tokenId = totalSupply() + 1;
            _safeMint(_to, tokenId);

            if (msg.sender == tx.origin) {
                creators[tokenId] = msg.sender;
            } else {
                creators[tokenId] = address(0);
            }
        }
    }

    function adminMint(uint256 _qty, address _to) external onlyOwner {
        require(_qty != 0, "NFT: minitum 1 nft");
        require(_to != address(0), "NFT: invalid address");
        require(totalSupply() + _qty <= maxSupply, "NFT: max supply reached");

        for (uint256 i = 0; i < _qty; i++) {
            _safeMint(_to, totalSupply() + 1);
        }
    }

    /**************************
     ***** VIEW FUNCTIONS *****
     *************************/
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 _id) public view virtual override returns (string memory) {
        require(_exists(_id), "ERC721Metadata: URI query for nonexistent token");
        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, _id.toString()))
                : "";
    }

    function tokensOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(_owner);
        uint256[] memory ids = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            ids[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return ids;
    }

    function exists(uint256 _id) external view returns (bool) {
        return _exists(_id);
    }

    function setBaseURI(string memory _newBaseURI) external onlyOwner {
        baseURI = _newBaseURI;
    }

    function clearStuckTokens(IERC20 erc20) external onlyOwner {
        uint256 balance = erc20.balanceOf(address(this));
        erc20.transfer(msg.sender, balance);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = royalties[_tokenId].receiver;
        if (royalties[_tokenId].rate > 0 && royalties[_tokenId].receiver != address(0)) {
            royaltyAmount = _salePrice * royalties[_tokenId].rate / 10000;
        }
    }

    function setRoyalty(uint256 _tokenId, address receiver, uint16 _royalty) external {
        require(creators[_tokenId] == msg.sender, "NFT: Invalid creator");
        require(receiver != address(0), "NFT: invalid royalty receiver");
        require(_royalty <= MAX_ROYALTY, "NFT: Invalid royalty percentage");

        royalties[_tokenId].receiver = receiver;
        royalties[_tokenId].rate = _royalty;
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        require(_maxSupply > maxSupply, "The max supply should larger than current value");
        maxSupply = _maxSupply;
    }

    function setMaxBatchQuantity(uint256 _batchQuantity) external onlyOwner {
        require(_batchQuantity >= 1 && _batchQuantity <= MAX_BATCH_QUANTITY, "Max batch quantity should between 1 to 1000");
        maxBatchQuantity = _batchQuantity;
    }
}
