pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

contract ARPRegistry {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    uint256 public constant SERVER_HOLDING = 100000 ether;
    uint256 public constant HOLDING_PER_DEVICE = 100 ether;
    uint256 public constant EXPIRED_DELAY = 30 days;
    uint256 public constant CAPACITY_MIN = 100;

    struct Server {
        uint32 ip;
        uint16 port;
        uint256 capacity;
        uint256 amount;
        uint256 expired;

        uint256 deviceCount;
    }

    ERC20 public arpToken;

    mapping (address => Server) public servers;
    address[] indexes;

    event Registered(address indexed server);
    event Unregistered(address indexed server);

    constructor(ERC20 _arpToken) public {
        require(_arpToken != address(0x0));
        arpToken = _arpToken;
    }

    function register(uint32 _ip, uint16 _port, uint256 _capacity, uint256 _amount) public {
        require(_ip != 0 && _port != 0);
        require(_capacity >= CAPACITY_MIN);
        require(_amount >= SERVER_HOLDING + HOLDING_PER_DEVICE * _capacity);

        Server storage s = servers[msg.sender];
        require(_capacity >= s.capacity);
        require(_amount >= s.amount);
        uint256 amount = _amount.sub(s.amount);
        require(arpToken.balanceOf(msg.sender) >= amount);
        require(arpToken.allowance(msg.sender, address(this)) >= amount);
        s.ip = _ip;
        s.port = _port;
        s.capacity = _capacity;
        s.amount = _amount;
        // solium-disable-next-line security/no-block-members
        s.expired = now + EXPIRED_DELAY;
        servers[msg.sender] = s;
        indexes.push(msg.sender);

        arpToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Registered(msg.sender);
    }

    function unregister() public {
        Server storage s = servers[msg.sender];
        require(s.ip != 0);
        // solium-disable-next-line security/no-block-members
        require(now >= s.expired);
        require(s.deviceCount == 0);
        uint256 amount = s.amount;
        delete servers[msg.sender];
        for (uint256 i = 0; i < indexes.length; i++) {
            if (indexes[i] == msg.sender) {
                for (uint256 j = i + 1; j < indexes.length; j++) {
                    indexes[j - 1] = indexes[j];
                }
                indexes.length = indexes.length - 1;
                break;
            }
        }

        arpToken.safeTransfer(msg.sender, amount);

        emit Unregistered(msg.sender);
    }

    function serverByIndex(
        uint256 _index
    )
        view
        public
        returns (
            address addr,
            uint32 ip,
            uint16 port,
            uint256 capacity,
            uint256 amount,
            uint256 expired,
            uint256 deviceCount
        )
    {
        require(_index < indexes.length);

        addr = indexes[_index];
        Server storage s = servers[addr];
        ip = s.ip;
        port = s.port;
        capacity = s.capacity;
        amount = s.amount;
        expired = s.expired;
        deviceCount = s.deviceCount;
    }

    function serverCount() view public returns (uint256) {
        return indexes.length;
    }
}
