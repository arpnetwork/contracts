pragma solidity ^0.4.23;

import "./ARPWallet.sol";

/**
 * @title ARPMultiTransferer
 * @dev A wallet that can be transfer ether & token to multiple addresses.
 */
contract ARPMultiTransferer is ARPWallet {
    constructor(address _owner) ARPWallet(_owner) public {
    }

    function multiTransfer(address[] _to, uint256 _value) onlyowner public {
        for (uint256 i = 0; i < _to.length; i++) {
            _to[i].transfer(_value);
        }
    }

    function multiTransferEx(address[] _to, uint256[] _values) onlyowner public {
        require(_to.length == _values.length);

        for (uint256 i = 0; i < _to.length; i++) {
            _to[i].transfer(_values[i]);
        }
    }

    function multiTransferToken(
        ERC20Basic _token,
        address[] _to,
        uint256 _value
    )
        onlyowner
        public
    {
        require(_token != address(0x0));

        for (uint256 i = 0; i < _to.length; i++) {
            _token.transfer(_to[i], _value);
        }
    }

    function multiTransferTokenEx(
        ERC20Basic _token,
        address[] _to,
        uint256[] _values
    )
        onlyowner
        public
    {
        require(_token != address(0x0));
        require(_to.length == _values.length);

        for (uint256 i = 0; i < _to.length; i++) {
            _token.transfer(_to[i], _values[i]);
        }
    }
}
