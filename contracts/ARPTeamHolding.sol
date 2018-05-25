pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/TokenTimelock.sol";

contract ARPTeamHolding is TokenTimelock {
    uint256 public constant WITHDRAWAL_DELAY = 365 * 2 days; // 2 years

    constructor(
        ERC20Basic token,
        address beneficiary,
        uint256 startTime
    )
        TokenTimelock(token, beneficiary, startTime + WITHDRAWAL_DELAY)
        public
    {
    }
}
