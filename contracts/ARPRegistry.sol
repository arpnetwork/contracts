pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

// solium-disable security/no-block-members, error-reason

contract ARPRegistry {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    uint256 public constant SERVER_HOLDING = 100000 ether;
    uint256 public constant DEVICE_HOLDING = 500 ether;
    uint256 public constant HOLDING_PER_DEVICE = 100 ether;
    uint256 public constant EXPIRED_DELAY = 30 days;
    uint256 public constant CAPACITY_MIN = 100;
    uint256 public constant DEVICE_UNBOUND_DELAY = 1 days;

    struct Server {
        uint32 ip;
        uint16 port;
        uint256 capacity;
        uint256 amount;
        uint256 expired;

        uint256 deviceCount;
    }

    struct Device {
        address server;
        uint256 amount;
        uint256 expired;
    }

    ERC20 public arpToken;

    mapping (address => Server) public servers;
    mapping (address => Device) public devices;
    address[] indexes;

    event Registered(address indexed server);
    event Unregistered(address indexed server);
    event DeviceBound(address indexed device, address indexed server);
    event DeviceUnbound(address indexed device, address indexed server);
    event DeviceExpired(address indexed device, address indexed server);

    constructor(ERC20 _arpToken) public {
        require(_arpToken != address(0x0));
        arpToken = _arpToken;
    }

    function register(uint32 _ip, uint16 _port, uint256 _capacity, uint256 _amount) public {
        require(_ip != 0 && _port != 0);
        require(_capacity >= CAPACITY_MIN);

        Server storage s = servers[msg.sender];
        bool added = s.ip == 0;
        require(_capacity >= s.capacity);
        require(_amount >= s.amount);
        require(_amount >= minHolding(_capacity - s.deviceCount));
        uint256 amount = _amount.sub(s.amount);
        require(arpToken.balanceOf(msg.sender) >= amount);
        require(arpToken.allowance(msg.sender, address(this)) >= amount);
        s.ip = _ip;
        s.port = _port;
        s.capacity = _capacity;
        s.amount = _amount;
        s.expired = now + EXPIRED_DELAY;
        servers[msg.sender] = s;

        if (added) {
            indexes.push(msg.sender);
        }

        arpToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Registered(msg.sender);
    }

    function unregister() public {
        Server storage s = servers[msg.sender];
        require(s.ip != 0);
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

    function bindDevice(address _server) public {
        require(devices[msg.sender].server == address(0x0));
        require(arpToken.balanceOf(msg.sender) >= DEVICE_HOLDING);
        require(arpToken.allowance(msg.sender, address(this)) >= DEVICE_HOLDING);

        Server storage s = servers[_server];
        require(s.deviceCount < s.capacity);
        require(s.amount >= SERVER_HOLDING + HOLDING_PER_DEVICE);
        s.amount = s.amount.sub(HOLDING_PER_DEVICE);
        s.deviceCount = s.deviceCount.add(1);
        servers[_server] = s;

        devices[msg.sender] = Device(_server, HOLDING_PER_DEVICE, 0);

        arpToken.safeTransferFrom(msg.sender, address(this), DEVICE_HOLDING);

        emit DeviceBound(msg.sender, _server);
    }

    function unbindDevice() public {
        require(devices[msg.sender].server != address(0x0));

        unbindDeviceInternal(msg.sender);
    }

    function unbindDeviceByServer(address _device) public {
        Device storage dev = devices[_device];
        require(dev.server == msg.sender);

        Server storage s = servers[msg.sender];
        if (now >= s.expired) {
            unbindDeviceInternal(_device);
        } else if (dev.expired == 0) {
            dev.expired = now + DEVICE_UNBOUND_DELAY;
            devices[_device] = dev;

            emit DeviceExpired(_device, msg.sender);
        } else if (now >= dev.expired) {
            require(dev.amount + s.amount >= minHolding(s.capacity - s.deviceCount + 1));
            unbindDeviceInternal(_device);
        } else {
            revert();
        }
    }

    function serverByIndex(
        uint256 _index
    )
        public
        view
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

    function serverCount() public view returns (uint256) {
        return indexes.length;
    }

    function unbindDeviceInternal(address _device) private {
        Device storage dev = devices[_device];
        address server = dev.server;
        uint256 amount = dev.amount;
        delete devices[_device];

        Server storage s = servers[server];
        s.amount = s.amount.add(amount);
        s.deviceCount = s.deviceCount.sub(1);
        servers[server] = s;

        arpToken.safeTransfer(_device, DEVICE_HOLDING);

        emit DeviceUnbound(_device, server);
    }

    function minHolding(uint256 capacity) private pure returns (uint256) {
        return SERVER_HOLDING + HOLDING_PER_DEVICE * capacity;
    }
}
