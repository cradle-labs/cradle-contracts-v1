// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/access/Ownable.sol";
import { OffChainExchangeAsset } from "./OffChainExchangeAsset.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract OffChainExchange {
    address public admin;
    event PriceUpdate(address indexed tokenId, uint64 indexed priceUSD);
    // this is for the smallests decimal of the token
    mapping(address => uint128) public assetPriceOracleStable;
    mapping(string=>OffChainExchangeAsset) public exchangeAssets;


    receive() external payable {
        // do nothing
    }

    fallback() external payable {
        // do nothing
    }

    modifier onlyAdmin(){
        require(msg.sender == admin, "Operation not permitted");
        _;
    }

    constructor(){
        admin = msg.sender;
    }

    function updateAssetStableMultiplier(address tokenId, uint64 priceUSD) public onlyAdmin() {
        assetPriceOracleStable[tokenId] = priceUSD;
        emit PriceUpdate(tokenId, priceUSD);
    }

    function getStableMultiplier(address tokenId) public view returns (uint128){
        return assetPriceOracleStable[tokenId];
    }

    function createAsset(string memory _name, string memory _symbol) payable public onlyAdmin() {
        OffChainExchangeAsset asset = new OffChainExchangeAsset{value: msg.value}(_name, _symbol);
        exchangeAssets[_name] = asset;
    }

    function mintAsset(string memory name, uint64 amount) public onlyAdmin() {
        exchangeAssets[name].mint(amount);
        address token = exchangeAssets[name].token();
        uint256 currentSupply = IERC20(token).totalSupply();

        // TODO: maybe emit something
    }

    function burnAsset(string memory name, uint64 amount) public onlyAdmin() {
        exchangeAssets[name].burn(amount);
        address token = exchangeAssets[name].token();

        // TODO: maybe emit again
    }

    function grantAssetKYC(string memory name, address account) public onlyAdmin() {
        exchangeAssets[name].grantKYC(account);
        // TODO: emit event
    }

    function getTokenAddress(string memory name) public view returns (address) {
        return exchangeAssets[name].token();
    }

    function purchaseAsset(string memory name, uint64 amount) public {
        OffChainExchangeAsset asset = exchangeAssets[name];
        address token = asset.token();

    }
    

}


interface IOffChainExchange {
    function getStableMultiplier(address tokenId) external view returns (uint128);
}