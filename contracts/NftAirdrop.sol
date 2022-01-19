// SPDX-License-Identifier: MIT

//** LFG Vesting Contract */
//** Author Xiao Shengguang : NFT Airdrop Contract 2022.1 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NftAirdrop is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    //using SafeERC20 for IERC20;

    struct WhitelistInfo {
        address wallet;
        uint256 nftAmount;
        uint256 distributedAmount;
        bool active;
    }

    /**
     *
     * @dev this event calls when new whitelist member joined to the pool
     *
     */
    event AddWhitelist(address wallet);

    /**
     *
     * @dev this event calls when new whitelist member is deactivated
     *
     */
    event DecafList(address wallet);

    /**
     *
     * @dev whitelistPools store all active whitelist member details.
     *
     */
    mapping(address => WhitelistInfo) public whitelistPools;

    /**
     *
     * @dev whitelistAddresses array of all active whitelist adresses, using array so can iterate all the keys.
     *
     */
    address [] public whitelistAddresses;


    IERC721 private _nftToken;

    /**
     *
     * @dev set the address as whitelist user address
     *
     * @param {address} address of the user
     *
     * @return {bool} return status of the whitelist
     *
     */
    function addWhitelists(
        address[] calldata _wallet,
        uint256[] calldata _nftAmount
    ) external onlyOwner returns (bool) {
        require(_wallet.length == _nftAmount.length, "Invalid array length");

        for (uint256 i = 0; i < _wallet.length; i++) {
            require(whitelistPools[_wallet[i]].wallet != _wallet[i], "Whitelist already available");

            whitelistPools[_wallet[i]].wallet = _wallet[i];
            whitelistPools[_wallet[i]].nftAmount = _nftAmount[i];
            whitelistPools[_wallet[i]].distributedAmount = 0;

            whitelistAddresses.push(_wallet[i]);

            emit AddWhitelist(_wallet[i]);
        }

        return true;
    }

    /**
     *
     * @dev set the address as whitelist user address
     *
     * @param {address} address of the user
     *
     * @return {Whitelist} return whitelist instance
     *
     */
    function getWhitelist(address _wallet) external view returns (WhitelistInfo memory) {
        require(whitelistPools[_wallet].wallet == _wallet, "Whitelist is not existing");

        return whitelistPools[_wallet];
    }

    /**
     *
     * @dev get the count of whitelist addresses
     *
     * @return count of whitelist addresses
     *
     */
    function getWhitelistCount() external view returns (uint256) {
        return whitelistAddresses.length;
    }

    /**
     *
     * @dev set LFG token address for contract
     *
     * @param {_token} address of IERC20 instance
     * @return {bool} return status of token address
     *
     */
    function setNftToken(IERC721 _token) external onlyOwner returns (bool) {
        _nftToken = _token;
        return true;
    }

    /**
     *
     * @dev getter function for deployed nft token address
     *
     * @return {address} return deployment address of lfg token
     *
     */
    function getNftToken() external view returns (address) {
        return address(_nftToken);
    }

    /**
     *
     * @dev distribute the token to the investors
     *
     * @param {address} wallet address of the investor
     *
     * @return {bool} return status of distribution
     *
     */
    function claimDistribution() external nonReentrant returns (bool) {
        require(whitelistPools[msg.sender].active, "User is not in whitelist");
        require(whitelistPools[msg.sender].distributedAmount < whitelistPools[msg.sender].nftAmount, "All nft has been claimed");

        // TODO: transfer NFT from nft collection contract to user

        return true;
    }

    function decafLists(
        address[] calldata _wallet
    ) external onlyOwner returns (bool) {
        for (uint256 i = 0; i < _wallet.length; i++) {
            require(whitelistPools[_wallet[i]].active, "Whitelist not exist or deactivated already");
            whitelistPools[_wallet[i]].active = false;

            emit DecafList(_wallet[i]);
        }

        return true;
    }
}
