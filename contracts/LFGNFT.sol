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
    uint256 public constant MAX_SUPPLY = 10000;

    // minters
    mapping(address => bool) public minters;

    // creators
    mapping(uint256 => address) public creators;

    // royalty percentage
    uint256 public royaltyPercent;

    // MAX royalty percent
    uint256 public constant MAX_ROYALTY = 1000;

    modifier onlyMinter() {
        require(minters[msg.sender], "NFT: Invalid minter");
        _;
    }

    constructor(uint256 _royaltyPercent) ERC721("LFGNFT", "LFGNFT") {
        require(_royaltyPercent <= MAX_ROYALTY, "Invalid royalty percentage");

        royaltyPercent = _royaltyPercent;
    }

    /**************************
     ***** MINT FUNCTIONS *****
     *************************/
    function mint(uint256 _qty, address _to) external onlyMinter {
        require(totalSupply() + _qty <= MAX_SUPPLY, "NFT: out of stock");
        require(_to != address(0), "NFT: invalid address");

        for (uint256 i = 0; i < _qty; i++) {
            _safeMint(_to, totalSupply() + 1);

            if (msg.sender == tx.origin) {
                creators[totalSupply() + 1] = msg.sender;
            } else {
                creators[totalSupply() + 1] = address(0);
            }
        }
    }

    function adminMint(uint256 _qty, address _to) external onlyOwner {
        require(_qty != 0, "NFT: minitum 1 nft");
        require(_to != address(0), "NFT: invalid address");
        require(totalSupply() + _qty <= MAX_SUPPLY, "NFT: max supply reached");

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

    function setMinter(address _account, bool _isMinter) external onlyOwner {
        require(_account != address(0), "NFT: invalid address");

        minters[_account] = _isMinter;
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
        receiver = creators[_tokenId];
        royaltyAmount = creators[_tokenId] == address(0)
            ? 0
            : (_salePrice * royaltyPercent) / 10000;
    }
}
