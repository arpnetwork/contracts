pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol";

/**
 * @title ARPWallet
 * @dev A wallet that can be transfer ether & token.
 */
contract ARPWallet {
    address public owner;

    modifier onlyowner {
        require(msg.sender == owner);
        _;
    }

    constructor(address _owner) public {
        if (_owner != address(0x0)) {
            owner = _owner;
        } else {
            owner = msg.sender;
        }
    }

    /**
     * @dev transfer ether for a specified address
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transfer(address _to, uint256 _value) onlyowner public {
        require(_to != address(0x0));

        // solium-disable-next-line security/no-call-value
        require(_to.call.value(_value)());
    }

    /**
     * @dev transfer token for a specified address
     * @param _token The ERC20 basic token contract.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transferToken(ERC20Basic _token, address _to, uint256 _value) onlyowner public {
        require(_token != address(0x0));
        require(_to != address(0x0));

        require(_token.transfer(_to, _value));
    }

    function() payable public {
    }
}
