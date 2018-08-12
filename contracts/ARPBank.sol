pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

// solium-disable security/no-block-members, error-reason

contract ARPBank {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    struct Account {
        uint256 id;
        uint256 amount;
        uint256 expired;
    }

    struct Check {
        uint256 id;
        uint256 spenderId;
        uint256 amount;
        uint256 paid;
        uint256 expired;
        address proxy;
    }

    ERC20 public arpToken;

    mapping (address => Account) public accounts;
    mapping (address => mapping (address => Check)) checks;

    event Deposit(address indexed owner, uint256 id, uint256 value, uint256 expired);
    event Withdrawal(address indexed owner, uint256 id, uint256 value);
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
        require(_value > 0);
        require(_expired == 0 || _expired > now);

        Account storage a = accounts[msg.sender];
        require(_expired >= a.expired || now >= a.expired);
        a.amount = a.amount.add(_value);
        a.expired = _expired;

        if (a.id == 0) {
            a.id = block.number;
        }

        arpToken.safeTransferFrom(msg.sender, address(this), _value);

        emit Deposit(msg.sender, a.id, _value, _expired);
    }

    function withdraw(uint256 _value, uint256 _expired) public {
        require(_value > 0);
        require(_expired == 0 || _expired > now);

        Account storage a = accounts[msg.sender];
        require(now >= a.expired);
        require(_value <= a.amount);
        uint256 id = a.id;
        a.id = block.number;
        a.amount = a.amount.sub(_value);
        a.expired = _expired;
        if (a.amount == 0) {
            delete accounts[msg.sender];
        }

        arpToken.safeTransfer(msg.sender, _value);

        emit Withdrawal(msg.sender, id, _value);
    }

    function updateAccountId() public {
        Account storage a = accounts[msg.sender];
        require(a.id != 0);
        require(now >= a.expired);
        a.id = block.number;

        emit Deposit(msg.sender, a.id, 0, a.expired);
    }

    function updateAccountExpired(uint256 _expired) public {
        require(_expired == 0 || _expired > now);

        Account storage a = accounts[msg.sender];
        require(a.id != 0);
        require(_expired >= a.expired || now >= a.expired);
        a.expired = _expired;

        emit Deposit(msg.sender, a.id, 0, _expired);
    }

    function approve(
        address _spender,
        uint256 _spenderId,
        uint256 _amount,
        uint256 _expired,
        address _proxy
    )
        public
    {
        require(_expired > now);

        Check storage c = checks[msg.sender][_spender];
        if (c.id == 0) {
            c.proxy = _proxy;
        }
        if (_amount >= c.amount) {
            increaseApproval(_spender, _spenderId, _amount.sub(c.amount), _expired);
        } else {
            decreaseApproval(_spender, _spenderId, c.amount.sub(_amount), _expired);
        }
    }

    function increaseApproval(
        address _spender,
        uint256 _spenderId,
        uint256 _value,
        uint256 _expired
    )
        public
    {
        require(_spenderId != 0);
        require(_spenderId == accounts[_spender].id);
        require(_expired > now);

        Account storage a = accounts[msg.sender];
        require(_value <= a.amount);
        require(_expired <= a.expired);
        a.amount = a.amount.sub(_value);

        Check storage c = checks[msg.sender][_spender];
        require(_expired >= c.expired);
        if (c.id == 0) {
            c.id = block.number;
        }
        c.spenderId = _spenderId;
        c.amount = c.amount.add(_value);
        c.expired = _expired;

        emit Approval(msg.sender, _spender, c.id, c.amount, _expired);
    }

    function decreaseApproval(
        address _spender,
        uint256 _spenderId,
        uint256 _value,
        uint256 _expired
    )
        public
    {
        require(_spenderId != 0);
        require(_spenderId == accounts[_spender].id);
        require(_value > 0);
        require(_expired > now);

        Check storage c = checks[msg.sender][_spender];
        require(now >= c.expired || _spenderId != c.spenderId);
        require(_value <= c.amount.sub(c.paid));
        c.id = block.number;
        c.amount = c.amount.sub(c.paid).sub(_value);
        c.paid = 0;
        c.expired = _expired;

        Account storage a = accounts[msg.sender];
        require(_expired <= a.expired);
        a.amount = a.amount.add(_value);

        emit Approval(msg.sender, _spender, c.id, c.amount, _expired);
    }

    function cancelApproval(address _spender) public {
        Check storage c = checks[msg.sender][_spender];
        require(now >= c.expired || accounts[_spender].id != c.spenderId);
        cancelApprovalInternal(msg.sender, _spender);
    }

    function cancelApprovalBySpender(address _owner) public {
        cancelApprovalInternal(_owner, msg.sender);
    }

    function cancelApprovalByProxy(address _owner, address _spender) public {
        Check storage c = checks[_owner][_spender];
        require(msg.sender == c.proxy);
        cancelApprovalInternal(_owner, _spender);
    }

    function cash(address _from, uint256 _amount, uint8 _v, bytes32 _r, bytes32 _s) public {
        Check storage c = checks[_from][msg.sender];
        require(_amount > c.paid);
        require(_amount <= c.amount);
        bytes32 hash = keccak256(abi.encodePacked(c.id, _from, msg.sender, _amount));
        require(ecrecover(hash, _v, _r, _s) == _from);

        uint256 amount = _amount.sub(c.paid);
        c.paid = _amount;

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
            uint256 spenderId,
            uint256 amount,
            uint256 paid,
            uint256 expired
        )
    {
        Check storage c = checks[_owner][_spender];
        id = c.id;
        spenderId = c.spenderId;
        amount = c.amount;
        paid = c.paid;
        expired = c.expired;
    }

    function cancelApprovalInternal(address _owner, address _spender) private {
        Check storage c = checks[_owner][_spender];
        require(c.id != 0);
        uint256 id = c.id;
        uint256 amount = c.amount.sub(c.paid);
        delete checks[_owner][_spender];

        if (amount > 0) {
            Account storage a = accounts[_owner];
            a.amount = a.amount.add(amount);
        }

        emit Approval(msg.sender, _spender, id, 0, 0);
    }
}
