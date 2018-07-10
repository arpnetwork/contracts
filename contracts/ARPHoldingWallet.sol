pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract ARPHoldingWallet {
    using SafeERC20 for ERC20;

    // Middle term holding
    uint256 constant MID_TERM   = 1 finney; // = 0.001 ether
    // Long term holding
    uint256 constant LONG_TERM  = 2 finney; // = 0.002 ether

    uint256 constant GAS_LIMIT  = 200000;

    address owner;

    // ERC20 basic token contract being held
    ERC20 arpToken;
    address midTermHolding;
    address longTermHolding;

    /// Initialize the contract
    constructor(address _owner, ERC20 _arpToken, address _midTermHolding, address _longTermHolding) public {
        owner = _owner;
        arpToken = _arpToken;
        midTermHolding = _midTermHolding;
        longTermHolding = _longTermHolding;
    }

    /*
     * PUBLIC FUNCTIONS
     */

    function() payable public {
        require(msg.sender == owner);

        if (msg.value == MID_TERM) {
            depositOrWithdraw(midTermHolding);
        } else if (msg.value == LONG_TERM) {
            depositOrWithdraw(longTermHolding);
        } else if (msg.value == 0) {
            drain();
        } else {
            revert();
        }
    }

    function depositOrWithdraw(address _holding) private {
        uint256 amount = arpToken.balanceOf(address(this));
        if (amount > 0) {
            arpToken.safeApprove(_holding, amount);
        }
        require(_holding.call.gas(GAS_LIMIT)());
        amount = arpToken.balanceOf(address(this));
        if (amount > 0) {
            arpToken.safeTransfer(msg.sender, amount);
        }
        msg.sender.transfer(msg.value);
    }

    /// Drains ARP.
    function drain() private {
        uint256 amount = arpToken.balanceOf(address(this));
        require(amount > 0);

        arpToken.safeTransfer(owner, amount);
    }
}
