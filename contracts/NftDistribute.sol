// SPDX-License-Identifier: MIT

//** NFT Distribute Contract */
//** Author Xiao Shengguang : NFT Distribute Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NftDistribute is Ownable, IERC721Receiver {
    /**
     *
     * @dev this event calls when distribute the NFT to user
     *
     */
    event DistrubuteNft(address wallet, uint256 tokenId);

    /**
     *
     * @dev this event calls when user update the NFT contract
     *
     */
    event SetLfgNft(IERC721 _nft);

    IERC721 public lfgNft;

    constructor(address _owner, IERC721 _nft) {
        require(_owner != address(0), "Invalid owner address");
        _transferOwnership(_owner);

        lfgNft = _nft;
    }

    /**
     *
     * @dev set nft address for contract
     *
     * @param {_nft} address of IERC721 instance
     * @return {bool} return status of token address
     *
     */
    function setNftToken(IERC721 _nft) external onlyOwner returns (bool) {
        lfgNft = _nft;
        emit SetLfgNft(_nft);
        return true;
    }

    /**
     *
     * @dev Distrubute the NFT to the given addresses
     *
     * @param _wallets addresses to distribute
     * @param _tokenIds NFTs to distribute
     *
     */
    function distributeNft(address[] calldata _wallets, uint256[] calldata _tokenIds)
        external
        onlyOwner
    {
        require(_wallets.length == _tokenIds.length, "Wallet and token Id count not match");
        for (uint256 i = 0; i < _wallets.length; i++) {
            lfgNft.safeTransferFrom(address(this), _wallets[i], _tokenIds[i]);

            emit DistrubuteNft(_wallets[i], _tokenIds[i]);
        }
    }

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
