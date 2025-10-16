// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/**
CradleAccounts
- act as the main asset holding accounts for all assets in the CradleProtocol
- Interface with tokens across the entire Suite of Cradle Products
- These include
    - Lending and Borrowing Pools
    - Orderbook Trade Settlements
    - Asset Bridging
 */

contract CradleAccount {
    event DepositReceived(address depositor, uint256 amount);
    /**
    the protocol address. The protocol acts as the main controller of this account and can deposit or withdraw assets 
     */
    address public constant PROTOCOL = address(0x1);
    /**
    an offchain identifier tied to this account
     */
    string private controller;
    /**
    bridgers have the ability to bridge assets either on chain or offchain, that means they can make bridge requests to the protocol
     */
    bool public isBridger = false;

    receive() external payable {
        emit DepositReceived(msg.sender, msg.value);
    }


    modifier onlyProtocol() {
        require(msg.sender == PROTOCOL, "Operation not authorised");
        _;
    }

    constructor(string memory _controller) onlyProtocol() {
        controller = _controller;
        // TODO: handle max associations
    }


    /**
    When withdrawals are occuring the account has to approve itself to spend the amount
     */
    function approveSelfSpend(uint256 amount, address asset) private {
        // TODO: approve spending
    }


    /**
    Depositing to the account can be handled by any wallet 
     */
    function deposit(address asset, uint256 amount) public payable {
        // TODO: check if token's associated then do the association 
        // TODO: approve spending from the user's account
    }

    /**
    Withdrawals handled by protocol to a wallet that's been pre specified offchain
     */
    function withdraw(address asset, uint256 amount, address to) public onlyProtocol() {
        // TODO: check if user has token associated then associate with user
        approveSelfSpend(amount, asset);
        // TODO: transfer asset to the caller
    }


    /**
    updateBridgingStatus:
    - set to either true or false to allow briding of assets on chain or off chain
     */
    function updateBridgingStatus(bool status) public onlyProtocol() {
        isBridger = status;
    }

}

/**
ICradleAccount
- interface for interaction
 */
interface ICradleAccount {
    function updateBridgingStatus(bool status) external;
    function withdraw(address asset, uint256 amount, address to) external;
}