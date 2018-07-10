pragma solidity ^0.4.23;

import "./ARPHoldingWallet.sol";

contract ARPHoldingWalletCreator {
    /* 
     * EVENTS
     */
    event Created(address indexed _owner, address _wallet);

    mapping (address => address) public wallets;
    ERC20 public arpToken;
    address public midTermHolding;
    address public longTermHolding;

    constructor(ERC20 _arpToken, address _midTermHolding, address _longTermHolding) public {
        arpToken = _arpToken;
        midTermHolding = _midTermHolding;
        longTermHolding = _longTermHolding;
    }

    function() public {
        require(wallets[msg.sender] == address(0x0));

        address wallet = new ARPHoldingWallet(msg.sender, arpToken, midTermHolding, longTermHolding);
        wallets[msg.sender] = wallet;

        emit Created(msg.sender, wallet);
    }
}
