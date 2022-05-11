//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./interfaces/ILFGNFT.sol";
import "./interfaces/IUserBlackList.sol";

contract LFGNFT is ILFGNFT, ERC721Enumerable, ERC721URIStorage, IERC2981, Ownable {
    // MAX supply of collection
    uint256 public maxSupply;

    // creators
    mapping(uint256 => address) public creators;

    struct RoyaltyInfo {
        address receiver; // The payment receiver of royalty
        uint16 rate; // The rate of the payment
    }

    // User Blocklist contract
    IUserBlackList userBlackListContract;

    // royalties
    mapping(uint256 => RoyaltyInfo) private royalties;

    // MAX royalty percent
    uint16 public constant MAX_ROYALTY = 2000;

    event Minted(address indexed minter, address indexed to, string uri, uint256 tokenId);

    event AdminMinted(
        address indexed minter,
        address indexed to,
        uint256[] tokenIds,
        string[] URIs
    );

    event SetRoyalty(uint256 tokenId, address receiver, uint256 rate);

    event SetMaxSupply(uint256 maxSupply);

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    constructor(address _owner, IUserBlackList _userBlackListContract) ERC721("LFGNFT", "LFGNFT") {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);

        userBlackListContract = _userBlackListContract;

        _registerInterface(_INTERFACE_ID_ERC2981);

        maxSupply = 10000;
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || _supportedInterfaces[interfaceId];
    }

    /**************************
     ***** MINT FUNCTIONS *****
     *************************/
    function mint(address _to, string memory uri) external override {
        require(!userBlackListContract.isBlackListed(msg.sender), "User is blacklisted");
        require(totalSupply() + 1 <= maxSupply, "NFT: out of stock");
        require(_to != address(0), "NFT: invalid address");

        // Using tokenId in the loop instead of totalSupply() + 1,
        // because totalSupply() changed after _safeMint function call.
        uint256 tokenId = totalSupply() + 1;
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, uri);
        if (msg.sender == tx.origin) {
            creators[tokenId] = msg.sender;
        } else {
            creators[tokenId] = address(0);
        }

        emit Minted(msg.sender, _to, uri, tokenId);
    }

    function adminMint(string[] calldata URIs, address _to) external onlyOwner {
        require(URIs.length > 0, "NFT: minitum 1 nft");
        require(_to != address(0), "NFT: invalid address");
        require(totalSupply() + URIs.length <= maxSupply, "NFT: max supply reached");
        uint256[] memory tokenIds = new uint256[](URIs.length);
        for (uint256 i = 0; i < URIs.length; i++) {
            uint256 tokenId = totalSupply() + 1;
            _safeMint(_to, tokenId);
            _setTokenURI(tokenId, URIs[i]);
            tokenIds[i] = tokenId;
        }

        emit AdminMinted(msg.sender, _to, tokenIds, URIs);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
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

    function clearStuckTokens(IERC20 erc20) external onlyOwner {
        uint256 balance = erc20.balanceOf(address(this));
        erc20.transfer(msg.sender, balance);
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        receiver = royalties[_tokenId].receiver;
        if (royalties[_tokenId].rate > 0 && royalties[_tokenId].receiver != address(0)) {
            royaltyAmount = (_salePrice * royalties[_tokenId].rate) / 10000;
        }
    }

    function setRoyalty(
        uint256 _tokenId,
        address _receiver,
        uint16 _royalty
    ) external {
        require(creators[_tokenId] == msg.sender, "NFT: Invalid creator");
        require(creators[_tokenId] == ownerOf(_tokenId), "NFT: Cannot set royalty after transfer");
        require(_receiver != address(0), "NFT: invalid royalty receiver");
        require(_royalty <= MAX_ROYALTY, "NFT: Invalid royalty percentage");

        royalties[_tokenId].receiver = _receiver;
        royalties[_tokenId].rate = _royalty;

        emit SetRoyalty(_tokenId, _receiver, _royalty);
    }

    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        require(_maxSupply > maxSupply, "The max supply should larger than current value");
        maxSupply = _maxSupply;

        emit SetMaxSupply(_maxSupply);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        require(!userBlackListContract.isBlackListed(from), "from address is blacklisted");
        require(!userBlackListContract.isBlackListed(to), "to address is blacklisted");
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }
}
