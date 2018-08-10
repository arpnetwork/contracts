pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

// solium-disable security/no-block-members, error-reason

contract ARPBank {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    struct Account {
        uint256 amount;
        uint256 expired;
    }

    struct Check {
        uint256 id;
        uint256 amount;
        uint256 paid;
        uint256 expired;
    }

    ERC20 public arpToken;

    mapping (address => Account) public accounts;
    mapping (address => mapping (address => Check)) checks;

    event Deposit(address indexed owner, uint256 value, uint256 expired);
    event Withdrawal(address indexed owner, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 id,
        uint256 value,
        uint256 expired
    );
    event Cashing(
        address indexed spender,
        address indexed owner,
        uint256 id,
        uint256 value
    );

    constructor(ERC20 _arpToken) public {
        require(_arpToken != address(0x0));
        arpToken = _arpToken;
    }

    function deposit(uint256 _value, uint256 _expired) public {
        Account storage a = accounts[msg.sender];
        require(_expired == 0 || _expired > now);
        require(_expired >= a.expired);
        a.amount = a.amount.add(_value);
        a.expired = _expired;

        arpToken.safeTransferFrom(msg.sender, address(this), _value);

        emit Deposit(msg.sender, _value, _expired);
    }

    function withdraw(uint256 _value) public {
        require(_value > 0);

        Account storage a = accounts[msg.sender];
        require(now >= a.expired);
        require(_value <= a.amount);
        a.amount = a.amount.sub(_value);
        if (a.amount == 0) {
            delete accounts[msg.sender];
        }

        arpToken.safeTransfer(msg.sender, _value);

        emit Withdrawal(msg.sender, _value);
    }

    function approve(
        address _spender,
        uint256 _id,
        uint256 _value,
        uint256 _expired
    )
        public
    {
        require(_id > 0);
        require(_value > 0);
        require(_expired > now);

        Check storage c = checks[msg.sender][_spender];
        require(_id == c.id || now >= c.expired);
        if (_id != c.id) {
            c.id = _id;
            c.amount = c.amount.sub(c.paid);
            c.paid = 0;
        }

        if (_value >= c.amount) {
            increaseApproval(_spender, _value.sub(c.amount), _expired);
        } else {
            decreaseApproval(_spender, c.amount.sub(_value), _expired);
        }
    }

    function increaseApproval(
        address _spender,
        uint256 _value,
        uint256 _expired
    )
        public
    {
        require(_expired > now);

        Account storage a = accounts[msg.sender];
        require(_value <= a.amount);
        require(_expired <= a.expired);
        a.amount = a.amount.sub(_value);

        Check storage c = checks[msg.sender][_spender];
        require(_expired >= c.expired);
        c.amount = c.amount.add(_value);
        c.expired = _expired;

        emit Approval(msg.sender, _spender, c.id, c.amount, _expired);
    }

    function decreaseApproval(
        address _spender,
        uint256 _value,
        uint256 _expired
    )
        public
    {
        require(_expired > now);

        Check storage c = checks[msg.sender][_spender];
        require(now >= c.expired);
        require(_value <= c.amount.sub(c.paid));
        c.amount = c.amount.sub(_value);
        c.expired = _expired;

        Account storage a = accounts[msg.sender];
        require(_expired <= a.expired);
        a.amount = a.amount.add(_value);

        emit Approval(msg.sender, _spender, c.id, c.amount, _expired);
    }

    function cancelApproval(address _spender) public {
        Check storage c = checks[msg.sender][_spender];
        require(now >= c.expired);
        uint256 id = c.id;
        uint256 value = c.amount.sub(c.paid);
        delete checks[msg.sender][_spender];

        Account storage a = accounts[msg.sender];
        a.amount = a.amount.add(value);

        emit Approval(msg.sender, _spender, id, 0, 0);
    }

    function cash(address _from, uint256 _value, uint8 _v, bytes32 _r, bytes32 _s) public {
        Check storage c = checks[_from][msg.sender];
        require(_value > c.paid);
        require(_value <= c.amount);
        bytes32 hash = keccak256(abi.encodePacked(c.id, _from, msg.sender, _value));
        require(ecrecover(hash, _v, _r, _s) == _from);

        uint256 amount = _value.sub(c.paid);
        c.paid = _value;

        arpToken.safeTransfer(msg.sender, amount);

        emit Cashing(msg.sender, _from, c.id, amount);
    }

    function allowance(
        address _owner,
        address _spender
    )
        public
        view
        returns (
            uint256 id,
            uint256 amount,
            uint256 paid,
            uint256 expired
        )
    {
        Check storage c = checks[_owner][_spender];
        id = c.id;
        amount = c.amount;
        paid = c.paid;
        expired = c.expired;
    }
}
