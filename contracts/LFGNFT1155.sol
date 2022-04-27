//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IUserBlackList.sol";

contract LFGNFT1155 is ERC1155, IERC2981, Ownable {
    using Strings for uint256;

    event SetRoyalty(uint256 tokenId, address receiver, uint256 rate);

    event CreateCollection(address indexed addr, bytes data);

    event CreateToken(
        address indexed creator,
        address indexed to,
        uint256 indexed tokenId,
        bytes data
    );

    event CreateTokenBatch(
        address indexed creator,
        address indexed to,
        uint256[] tokenIds,
        bytes data
    );

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

    struct Collection {
        address initiator;
        uint256[] ids;
    }

    // tokens in collection
    mapping(bytes => Collection) public collections;

    // MAX royalty percent
    uint16 public constant MAX_ROYALTY = 2000;

    IUserBlackList userBlackListContract;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    constructor(
        address _owner,
        IUserBlackList _userBlackListContract,
        string memory uri_
    ) ERC1155(uri_) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);

        userBlackListContract = _userBlackListContract;

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

    function createCollection(bytes calldata _data) external {
        require(!userBlackListContract.isBlackListed(msg.sender), "User is blacklisted");
        require(_data.length > 0, "Invalid collection name");
        require(collections[_data].initiator == address(0), "Collection already created");
        collections[_data].initiator = msg.sender;

        emit CreateCollection(msg.sender, _data);
    }

    function _create(
        address _to,
        uint256 _initialSupply,
        bytes calldata _data
    ) internal returns (uint256) {
        require(!userBlackListContract.isBlackListed(msg.sender), "User is blacklisted");
        uint256 _id = _getNextTokenID();
        _incrementTokenTypeId();
        creators[_id] = msg.sender;

        if (_initialSupply > 0) {
            require(_to != address(0), "NFT: invalid address");
            _mint(_to, _id, _initialSupply, _data);
        }

        tokenSupply[_id] = _initialSupply;

        if (_data.length > 0) {
            // Add Id to collections.
            collections[_data].ids.push(_id);
        }

        return _id;
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
        if (_data.length > 0) {
            require(collections[_data].initiator != address(0), "Collection doesn't exist");
            // If the collection already exists, then only the same user can add to the collection.
            require(
                tx.origin == collections[_data].initiator,
                "Only the same user can add to collection"
            );
        }

        uint256 tokenId = _create(_to, _initialSupply, _data);

        emit CreateToken(msg.sender, _to, tokenId, _data);
        return tokenId;
    }

    function createBatch(
        address _to,
        uint256 _quantity,
        uint256 _initialSupply,
        bytes calldata _data
    ) external returns (uint256[] memory) {
        require(_quantity > 0, "Invalid quantity");

        if (_data.length > 0) {
            require(collections[_data].initiator != address(0), "Collection doesn't exist");
            // If the collection already exists, then only the same user can add to the collection.
            require(
                tx.origin == collections[_data].initiator,
                "Only the same user can add to collection"
            );
        }

        uint256[] memory ids = new uint256[](_quantity);
        for (uint256 i = 0; i < _quantity; i++) {
            ids[i] = _create(_to, _initialSupply, _data);
        }

        emit CreateTokenBatch(msg.sender, _to, ids, _data);

        return ids;
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
        require(!userBlackListContract.isBlackListed(msg.sender), "User is blacklisted");
        require(_to != address(0), "NFT: invalid address");
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
        require(!userBlackListContract.isBlackListed(msg.sender), "User is blacklisted");
        require(_to != address(0), "NFT: invalid address");

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(creators[_id] == msg.sender, "ERC1155Tradable#batchMint: ONLY_CREATOR_ALLOWED");

            uint256 quantity = _quantities[i];
            require(_id > 0, "Invalid token id");
            require(quantity > 0, "Invalid quantity");

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
        require(
            balanceOf(msg.sender, _tokenId) == tokenSupply[_tokenId],
            "NFT: Cannot set royalty after transfer"
        );
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
        return collections[_collectionTag].ids;
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

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        require(!userBlackListContract.isBlackListed(from), "from address is blacklisted");
        require(!userBlackListContract.isBlackListed(to), "to address is blacklisted");
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
