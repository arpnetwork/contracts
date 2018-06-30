pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/Math.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract ARPMidTermHolding {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;
    using Math for uint256;

    // During the first 31 days of deployment, this contract opens for deposit of ARP.
    uint256 public constant DEPOSIT_PERIOD      = 31 days; // = 1 months

    // 8 months after deposit, user can withdrawal all his/her ARP.
    uint256 public constant WITHDRAWAL_DELAY    = 240 days; // = 8 months

    // Ower can drain all remaining ARP after 3 years.
    uint256 public constant DRAIN_DELAY         = 1080 days; // = 3 years.

    // 20% bonus ARP return
    uint256 public constant BONUS_SCALE         = 5;

    // ERC20 basic token contract being held
    ERC20 public arpToken;
    address public owner;
    uint256 public arpDeposited;
    uint256 public depositStartTime;
    uint256 public depositStopTime;

    struct Record {
        uint256 amount;
        uint256 timestamp;
    }

    mapping (address => Record) records;

    /* 
     * EVENTS
     */

    /// Emitted when all ARP are drained.
    event Drained(uint256 _amount);

    /// Emitted for each sucuessful deposit.
    uint256 public depositId = 0;
    event Deposit(uint256 _depositId, address indexed _addr, uint256 _amount, uint256 _bonus);

    /// Emitted for each sucuessful withdrawal.
    uint256 public withdrawId = 0;
    event Withdrawal(uint256 _withdrawId, address indexed _addr, uint256 _amount);

    /// Initialize the contract
    constructor(ERC20 _arpToken, address _owner, uint256 _depositStartTime) public {
        require(_owner != address(0));

        arpToken = _arpToken;
        owner = _owner;
        depositStartTime = _depositStartTime;
        depositStopTime = _depositStartTime.add(DEPOSIT_PERIOD);
    }

    /*
     * PUBLIC FUNCTIONS
     */

    /// Drains ARP.
    function drain() public {
        require(msg.sender == owner);
        // solium-disable-next-line security/no-block-members
        require(now >= depositStartTime.add(DRAIN_DELAY));

        uint256 balance = arpToken.balanceOf(address(this));
        require(balance > 0);

        arpToken.safeTransfer(owner, balance);

        emit Drained(balance);
    }

    function() public {
        // solium-disable-next-line security/no-block-members
        if (now >= depositStartTime && now < depositStopTime) {
            deposit();
        // solium-disable-next-line security/no-block-members
        } else if (now > depositStopTime){
            withdraw();
        } else {
            revert();
        }
    }

    /// Gets the balance of the specified address.
    function balanceOf(address _owner) view public returns (uint256) {
        return records[_owner].amount;
    }

    /// Gets the withdrawal timestamp of the specified address.
    function withdrawalTimeOf(address _owner) view public returns (uint256) {
        return records[_owner].timestamp.add(WITHDRAWAL_DELAY);
    }

    /// Deposits ARP.
    function deposit() private {
        uint256 amount = arpToken
            .balanceOf(msg.sender)
            .min256(arpToken.allowance(msg.sender, address(this)));
        require(amount > 0);

        Record storage record = records[msg.sender];
        record.amount = record.amount.add(amount);
        // solium-disable-next-line security/no-block-members
        record.timestamp = now;
        records[msg.sender] = record;

        arpDeposited = arpDeposited.add(amount);

        uint256 bonus = amount.div(BONUS_SCALE);
        if (bonus > 0) {
            arpToken.safeTransferFrom(owner, address(this), bonus);
            arpToken.safeTransfer(msg.sender, bonus);
        }
        arpToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Deposit(depositId++, msg.sender, amount, bonus);
    }

    /// Withdraws ARP.
    function withdraw() private {
        require(arpDeposited > 0);

        Record storage record = records[msg.sender];
        require(record.amount > 0);
        // solium-disable-next-line security/no-block-members
        require(now >= record.timestamp.add(WITHDRAWAL_DELAY));
        uint256 amount = record.amount;
        delete records[msg.sender];

        arpDeposited = arpDeposited.sub(amount);

        arpToken.safeTransfer(msg.sender, amount);

        emit Withdrawal(withdrawId++, msg.sender, amount);
    }
}
