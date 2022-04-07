//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LFGNFT1155 is ERC1155, IERC2981, Ownable {
    using Strings for uint256;

    event SetRoyalty(uint256 tokenId, address receiver, uint256 rate);
    event SetCreatorWhitelist(address indexed creator, bool isWhitelist);

    uint256 private _currentTokenID = 0;
    mapping(uint256 => address) public creators;

    // The total supply for token id, it is public so web3 can read it.
    mapping(uint256 => uint256) public tokenSupply;

    struct RoyaltyInfo {
        address receiver; // The payment receiver of royalty
        uint16 rate; // The rate of the payment
    }

    // royalties
    mapping(uint256 => RoyaltyInfo) public royalties;

    // tokens in collection
    mapping(bytes => uint256[]) private collectionTokens;

    mapping(address => bool) public creatorWhiteLists;

    // MAX royalty percent
    uint16 public constant MAX_ROYALTY = 2000;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    constructor(address _owner, string memory uri_) ERC1155(uri_) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);

        _registerInterface(_INTERFACE_ID_ERC2981);
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
        override(ERC1155, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Require msg.sender to be the creator of the token id
     */
    modifier creatorOnly(uint256 _id) {
        require(creators[_id] == msg.sender, "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED");
        _;
    }

    /**
     * @dev Creates a new token type and assigns _initialSupply to an address
     * NOTE: remove onlyOwner if you want third parties to create new tokens on your contract (which may change your IDs)
     * @param _to address of the first owner of the token
     * @param _initialSupply amount to supply the first owner
     * @param _data Data to pass if receiver is contract
     * @return The newly created token ID
     */
    function create(
        address _to,
        uint256 _initialSupply,
        bytes calldata _data
    ) external returns (uint256) {
        require(creatorWhiteLists[msg.sender], "Address is not in creator whitelist");

        uint256 _id = _getNextTokenID();
        _incrementTokenTypeId();
        creators[_id] = msg.sender;

        if (_initialSupply > 0) {
            _mint(_to, _id, _initialSupply, _data);
        }
        tokenSupply[_id] = _initialSupply;

        // Add Id to collections.
        collectionTokens[_data].push(_id);
        return _id;
    }

    /**
     * @dev Mints some amount of tokens to an address
     * @param _to          Address of the future owner of the token
     * @param _id          Token ID to mint
     * @param _quantity    Amount of tokens to mint
     * @param _data        Data to pass if receiver is contract
     */
    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public creatorOnly(_id) {
        require(_id > 0, "Invalid token id");
        require(_quantity > 0, "Invalid quantity");
        _mint(_to, _id, _quantity, _data);
        tokenSupply[_id] += _quantity;
    }

    /**
     * @dev Mint tokens for each id in _ids
     * @param _to          The address to mint tokens to
     * @param _ids         Array of ids to mint
     * @param _quantities  Array of amounts of tokens to mint per id
     * @param _data        Data to pass if receiver is contract
     */
    function mintBatch(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(creators[_id] == msg.sender, "ERC1155Tradable#batchMint: ONLY_CREATOR_ALLOWED");
            uint256 quantity = _quantities[i];
            tokenSupply[_id] += quantity;
        }
        _mintBatch(_to, _ids, _quantities, _data);
    }

    function setURI(string memory newuri) external onlyOwner {
        _setURI(newuri);
    }

    /**
     * @dev calculates the next token ID based on value of _currentTokenID
     * @return uint256 for the next token ID
     */
    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID + 1;
    }

    /**
     * @dev increments the value of _currentTokenID
     */
    function _incrementTokenTypeId() private {
        _currentTokenID++;
    }

    function setRoyalty(
        uint256 _tokenId,
        address _receiver,
        uint16 _royalty
    ) external {
        require(creators[_tokenId] == msg.sender, "NFT: Invalid creator");
        require(_receiver != address(0), "NFT: invalid royalty receiver");
        require(_royalty <= MAX_ROYALTY, "NFT: Invalid royalty percentage");

        royalties[_tokenId].receiver = _receiver;
        royalties[_tokenId].rate = _royalty;

        emit SetRoyalty(_tokenId, _receiver, _royalty);
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

    /**
     * @dev get the tokens of a collection
     * @return uint256[] array of token ID
     */
    function getCollectionTokens(bytes calldata _collectionTag)
        external
        view
        returns (uint256[] memory)
    {
        return collectionTokens[_collectionTag];
    }

    function setCreatorWhitelist(address _addr, bool _isWhitelist) external onlyOwner {
        creatorWhiteLists[_addr] = _isWhitelist;

        emit SetCreatorWhitelist(_addr, _isWhitelist);
    }

    function uri(uint256 _id) public view virtual override returns (string memory) {
        require(_exists(_id), "ERC1155Metadata: URI query for nonexistent token");
        string memory currentBaseURI = ERC1155.uri(_id);
        return
            bytes(currentBaseURI).length > 0
                ? string(abi.encodePacked(currentBaseURI, _id.toString()))
                : "";
    }

    function _exists(uint256 _tokenId) internal view returns (bool) {
        return creators[_tokenId] != address(0);
    }
}
