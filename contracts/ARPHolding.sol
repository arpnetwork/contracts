pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol";

contract ARPHolding is TokenTimelock {
    uint256 public constant WITHDRAWAL_DELAY = 365 days; // 1 year

    constructor(
        ERC20Basic token,
        address beneficiary,
        uint256 startTime
    )
        TokenTimelock(token, beneficiary, startTime + WITHDRAWAL_DELAY)
        public
    {
    }

    function() public {
        release();
    }
}
