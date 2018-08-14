pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

// solium-disable security/no-block-members, error-reason

contract ARPBank {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    uint256 public constant PERMANENT = 0;

    struct Check {
        uint256 id;
        uint256 amount;
        uint256 paid;
        uint256 expired;
        address proxy;
    }

    ERC20 public arpToken;

    mapping (address => uint256) balances;
    mapping (address => mapping (address => Check)) checks;

    event Deposit(address indexed owner, uint256 value);
    event Withdrawal(address indexed owner, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 id,
        uint256 value,
        uint256 expired,
        address proxy
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

    function deposit(uint256 _value) public {
        require(_value > 0);

        balances[msg.sender] = balances[msg.sender].add(_value);

        arpToken.safeTransferFrom(msg.sender, address(this), _value);

        emit Deposit(msg.sender, _value);
    }

    function withdraw(uint256 _value) public {
        require(_value > 0);
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);

        arpToken.safeTransfer(msg.sender, _value);

        emit Withdrawal(msg.sender, _value);
    }

    function approve(
        address _spender,
        uint256 _amount,
        uint256 _expired,
        address _proxy
    )
        public
    {
        require(_spender != address(0x0));
        require(_expired == PERMANENT || _expired > now);

        Check storage c = checks[msg.sender][_spender];
        if (c.id == 0) {
            c.id = block.number;
            c.expired = _expired;
            c.proxy = _proxy;
        } else {
            require(_proxy == c.proxy);
            if (c.expired != PERMANENT && now >= c.expired) {
                c.id = block.number;
                // DO NOT MODIFY EXPIRED HERE
            }
        }

        if (_amount >= c.amount) {
            increaseApproval(_spender, _amount.sub(c.amount), _expired);
        } else {
            decreaseApproval(_spender, c.amount.sub(_amount), _expired);
        }
    }

    function approveByProxy(
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _expired,
        uint256 _signExpired,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        public
    {
        require(_owner != address(0x0));
        require(_spender != address(0x0));
        require(_expired == PERMANENT || _expired > now);
        require(_signExpired > now);

        // sign(owner, spender, amount, expired, proxy, signExpired)
        bytes32 hash = keccak256(
            abi.encodePacked(
                _owner,
                _spender,
                _amount,
                _expired,
                msg.sender,
                _signExpired
            )
        );
        require(ecrecover(hash, _v, _r, _s) == _owner);

        Check storage c = checks[_owner][_spender];
        require(c.id == 0);
        c.id = block.number;
        c.amount = _amount;
        c.expired = _expired;
        c.proxy = msg.sender;

        if (_amount > 0) {
            require(_amount <= balances[_owner]);
            balances[_owner] = balances[_owner].sub(_amount);
        }

        emit Approval(_owner, _spender, c.id, c.amount, _expired, c.proxy);
    }

    function increaseApproval(
        address _spender,
        uint256 _value,
        uint256 _expired
    )
        public
    {
        require(_spender != address(0x0));
        require(_value <= balances[msg.sender]);
        require(_expired == PERMANENT || _expired > now);

        Check storage c = checks[msg.sender][_spender];
        require(c.id != 0);
        require(
            _expired == PERMANENT ||
            (c.expired != PERMANENT && _expired >= c.expired));

        if (_value > 0) {
            balances[msg.sender] = balances[msg.sender].sub(_value);
            c.amount = c.amount.add(_value);
        }
        c.expired = _expired;

        emit Approval(msg.sender, _spender, c.id, c.amount, _expired, c.proxy);
    }

    function decreaseApproval(
        address _spender,
        uint256 _value,
        uint256 _expired
    )
        public
    {
        require(_spender != address(0x0));
        require(_value > 0);
        require(_expired == PERMANENT || _expired > now);

        Check storage c = checks[msg.sender][_spender];
        require(c.id != 0);
        require(c.expired != PERMANENT && now >= c.expired);
        require(_value <= c.amount.sub(c.paid));

        c.amount = c.amount.sub(_value);
        c.expired = _expired;

        balances[msg.sender] = balances[msg.sender].add(_value);

        emit Approval(msg.sender, _spender, c.id, c.amount, _expired, c.proxy);
    }

    function cancelApproval(address _spender) public {
        Check storage c = checks[msg.sender][_spender];
        require(c.expired != PERMANENT && now >= c.expired);
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

    function cash(
        address _from,
        uint256 _amount,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        public
    {
        Check storage c = checks[_from][msg.sender];
        require(_amount > c.paid);
        require(_amount <= c.amount);
        bytes32 hash = keccak256(
            abi.encodePacked(c.id, _from, msg.sender, _amount)
        );
        require(ecrecover(hash, _v, _r, _s) == _from);

        uint256 amount = _amount.sub(c.paid);
        c.paid = _amount;

        arpToken.safeTransfer(msg.sender, amount);

        emit Cashing(msg.sender, _from, c.id, amount);
    }

    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
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
            uint256 expired,
            address proxy
        )
    {
        Check storage c = checks[_owner][_spender];
        id = c.id;
        amount = c.amount;
        paid = c.paid;
        expired = c.expired;
        proxy = c.proxy;
    }

    function cancelApprovalInternal(address _owner, address _spender) private {
        Check storage c = checks[_owner][_spender];
        require(c.id != 0);
        uint256 id = c.id;
        uint256 value = c.amount.sub(c.paid);
        delete checks[_owner][_spender];

        if (value > 0) {
            balances[_owner] = balances[_owner].add(value);
        }

        emit Approval(msg.sender, _spender, id, 0, 0, address(0x0));
    }
}
