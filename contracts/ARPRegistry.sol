pragma solidity ^0.4.23;

import "./ARPBank.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/SafeERC20.sol";

// solium-disable security/no-block-members, error-reason

contract ARPRegistry {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    uint256 public constant PERMANENT = 0;

    uint256 public constant SERVER_HOLDING = 100000 ether;
    uint256 public constant DEVICE_HOLDING = 500 ether;
    uint256 public constant EXPIRED_DELAY = 1 days;

    struct Server {
        uint32 ip;
        uint16 port;
        uint256 size;
        uint256 expired;
    }

    struct Binding {
        address server;
        uint256 expired;
    }

    ARPBank public arpBank;

    mapping (address => Server) public servers;
    mapping (bytes32 => Binding) public bindings;
    address[] indexes;

    event ServerRegistered(address indexed server);
    event ServerUnregistered(address indexed server);
    event ServerExpired(address indexed server);
    event DeviceBound(address indexed device, address indexed server);
    event DeviceUnbound(address indexed device, address indexed server);
    event DeviceBoundExpired(address indexed device, address indexed server);
    event AppBound(address indexed app, address indexed server);
    event AppUnbound(address indexed app, address indexed server);
    event AppBoundExpired(address indexed app, address indexed server);

    constructor(ARPBank _arpBank) public {
        require(_arpBank != address(0x0));
        arpBank = _arpBank;
    }

    function registerServer(uint32 _ip, uint16 _port) public {
        require(_ip != 0 && _port != 0);

        (
            ,
            uint256 amount,
            ,
            uint256 expired,
            address proxy
        ) = arpBank.allowance(msg.sender, address(this));
        require(amount >= SERVER_HOLDING);
        require(expired == PERMANENT);
        require(proxy == address(0x0));

        Server storage s = servers[msg.sender];
        require(s.ip == 0);
        s.ip = _ip;
        s.port = _port;

        indexes.push(msg.sender);

        emit ServerRegistered(msg.sender);
    }

    function updateServer(uint32 _ip, uint16 _port) public {
        require(_ip != 0 && _port != 0);

        Server storage s = servers[msg.sender];
        require(s.ip != 0);

        s.ip = _ip;
        s.port = _port;
    }

    function unregisterServer() public {
        Server storage s = servers[msg.sender];
        require(s.ip != 0);

        if (s.expired != PERMANENT) {
            require(now >= s.expired);
            require(s.size == 0);

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

            arpBank.cancelApprovalBySpender(msg.sender);

            emit ServerUnregistered(msg.sender);
        } else {
            s.expired = now + EXPIRED_DELAY;

            emit ServerExpired(msg.sender);
        }
    }

    function bindDevice(
        address _server,
        uint256 _amount,
        uint256 _expired,
        uint256 _signExpired,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    )
        public
    {
        require(_server != address(0x0));
        require(_expired == PERMANENT || _expired > now);
        require(_signExpired > now);

        Binding storage b = bindings[bytes32(msg.sender)];
        if (b.server != address(0x0)) {
            unbindDeviceInternal(msg.sender);
        } else {
            // Checks device approval
            (
                ,
                uint256 amount,
                ,
                uint256 expired,
                address proxy
            ) = arpBank.allowance(msg.sender, address(this));
            require(amount >= DEVICE_HOLDING);
            require(expired == PERMANENT);
            require(proxy == address(0x0));
        }

        b.server = _server;

        Server storage s = servers[_server];
        require(s.ip != 0);
        require(s.expired == PERMANENT);
        s.size = s.size.add(1);

        arpBank.approveByProxy(
            _server,
            msg.sender,
            _amount,
            _expired,
            _signExpired,
            _v,
            _r,
            _s
        );

        emit DeviceBound(msg.sender, _server);
    }

    function unbindDevice() public {
        if (bindings[bytes32(msg.sender)].server != address(0x0)) {
            unbindDeviceInternal(msg.sender);
        }

        arpBank.cancelApprovalBySpender(msg.sender);
    }

    function unbindDeviceByServer(address _device) public {
        Binding storage b = bindings[bytes32(_device)];
        require(b.server == msg.sender);

        uint256 expired = servers[msg.sender].expired;
        if (expired != PERMANENT && now >= expired) {
            unbindDeviceInternal(_device);
        } else if (b.expired != PERMANENT) {
            require(now >= b.expired);
            unbindDeviceInternal(_device);
        } else {
            b.expired = now + EXPIRED_DELAY;

            emit DeviceBoundExpired(_device, msg.sender);
        }
    }

    function bindApp(address _server) public {
        require(_server != address(0x0));

        bytes32 key = keccak256(abi.encodePacked(msg.sender, _server));
        Binding storage b = bindings[key];
        require(b.server == address(0x0));

        b.server = _server;

        Server storage s = servers[_server];
        require(s.ip != 0);
        require(s.expired == PERMANENT);

        emit AppBound(msg.sender, _server);
    }

    function unbindApp(address _server) public {
        require(_server != address(0x0));

        bytes32 key = keccak256(abi.encodePacked(msg.sender, _server));
        Binding storage b = bindings[key];
        require(b.server != address(0x0));

        Server storage s = servers[_server];

        if (s.ip == 0 || s.expired != PERMANENT && now >= s.expired) {
            unbindAppInternal(msg.sender, _server);
        } else if (b.expired != PERMANENT) {
            require(now >= b.expired);
            unbindAppInternal(msg.sender, _server);
        } else {
            b.expired = now + EXPIRED_DELAY;

            emit AppBoundExpired(msg.sender, _server);
        }
    }

    function unbindAppByServer(address _app) public {
        require(_app != address(0x0));

        unbindAppInternal(_app, msg.sender);
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
            uint256 size,
            uint256 expired
        )
    {
        require(_index < indexes.length);

        addr = indexes[_index];
        Server storage s = servers[addr];
        ip = s.ip;
        port = s.port;
        size = s.size;
        expired = s.expired;
    }

    function serverCount() public view returns (uint256) {
        return indexes.length;
    }

    function unbindDeviceInternal(address _device) private {
        bytes32 key = bytes32(_device);
        address server = bindings[key].server;
        require(server != address(0x0));
        delete bindings[key];

        Server storage s = servers[server];
        s.size = s.size.sub(1);

        cancelApprovalByProxy(server, _device);

        emit DeviceUnbound(_device, server);
    }

    function unbindAppInternal(address _app, address _server) private {
        bytes32 key = keccak256(abi.encodePacked(_app, _server));
        require(bindings[key].server != address(0x0));
        delete bindings[key];

        cancelApprovalByProxy(_app, _server);

        emit AppUnbound(_app, _server);
    }

    function cancelApprovalByProxy(address _owner, address _spender) private {
        (,,,, address proxy) = arpBank.allowance(_owner, _spender);
        if (proxy == address(this)) {
            arpBank.cancelApprovalByProxy(_owner, _spender);
        }
    }
}
