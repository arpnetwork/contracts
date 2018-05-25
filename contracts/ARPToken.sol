pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract ARPToken is StandardToken {
    string public name = "ARP";
    string public symbol = "ARP";
    uint8 public decimals = 18;
    uint256 public totalSupply = 10 ** 27;

    constructor() public {
        balances[msg.sender] = totalSupply;
    }

    function() payable public {
        revert();
    }
}
