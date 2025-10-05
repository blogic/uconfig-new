# uconfig WebSocket Protocol

## 1. Transport

WebSocket connection to `/uconfig` endpoint using the `ui` subprotocol.

## 2. JSON-RPC 2.0 Format

### Request
```json
{
  "jsonrpc": "2.0",
  "method": "method-name",
  "params": { },
  "id": 1
}
```

### Success Response
```json
{
  "jsonrpc": "2.0",
  "result": { },
  "id": 1
}
```

### Error Response
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32601,
    "message": "Method not found",
    "data": { }
  },
  "id": 1
}
```

## 3. Error Codes

| Code | Message | Description |
|------|---------|-------------|
| -32700 | Parse error | Invalid JSON received |
| -32600 | Invalid Request | Request does not conform to JSON-RPC 2.0 |
| -32601 | Method not found | Method does not exist |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Server internal error |
| -32001 | Login required | Authentication required for this method |
| -32000 | Invalid password | Authentication failed |

## 4. Methods

### ping

Keepalive message to maintain the WebSocket connection.

**Request:**
```json
{"jsonrpc": "2.0", "method": "ping", "params": null, "id": 1}
```

**Success Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 1}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 1}
```

### login

Authenticates the WebSocket connection using a password. Once authenticated, the connection can invoke protected methods. The response includes board information and a list of installed modules.

**Request:**
```json
{"jsonrpc": "2.0", "method": "login", "params": {"password": "secret"}, "id": 2}
```

**Success Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "board": {
      "model_name": "OpenWrt One",
      "model_id": "openwrt,one"
    },
    "modules": ["adguardhome", "batman-adv"]
  },
  "id": 2
}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32000, "message": "Invalid password"}, "id": 2}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 2}
```

**Response Fields:**
- `success`: Boolean indicating successful authentication
- `board`: Object containing board information from `/etc/board.json`
- `modules`: Array of strings representing installed module names from `/etc/uconfig/modules/`

### logout

Clears the authentication state for the current WebSocket connection.

**Request:**
```json
{"jsonrpc": "2.0", "method": "logout", "params": null, "id": 2}
```

**Success Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 2}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 2}
```

### setup-wizard

Completes the initial device setup wizard. This method is only available when the device has not been configured (when the `setup-required` event is sent). After successful completion, the device transitions to normal operation mode and sends the `login-required` event.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "setup-wizard",
  "params": {
    "mode": "router",
    "password": "aaaaaaaa",
    "timezone": "Europe/Berlin",
    "ssid": "openwrt",
    "wifi_password": "aaaaaaaa",
    "security": "maximum",
    "uplink_addressing": "static",
    "uplink_subnet": "192.168.42.255/24",
    "uplink_gateway": "192.168.42.1",
    "uplink_dns": "192.168.42.1"
  },
  "id": 3
}
```

**Success Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 3}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 3}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Configuration validation failed", "data": {"exit_code": 1}}, "id": 3}
```

**Parameters:**
- `mode`: Device mode - `"router"` or `"ap"`
- `password`: Admin password (8-64 characters) - updates `/etc/uconfig/webui/credentials`
- `timezone`: System timezone (e.g., `"Europe/Berlin"`)
- `ssid`: WiFi network name
- `wifi_password`: WiFi password (8-64 characters)
- `security`: WiFi security level - `"maximum"` uses WPA2/WPA3 encryption
- `uplink_addressing`: Uplink IP addressing - `"static"` or `"dynamic"`
- `uplink_subnet`: Static IP subnet (required if `uplink_addressing` is `"static"`)
- `uplink_gateway`: Static IP gateway (required if `uplink_addressing` is `"static"`)
- `uplink_dns`: Static DNS server (required if `uplink_addressing` is `"static"`)

**Workflow:**
1. Client receives `setup-required` event upon connection
2. Client presents setup wizard UI
3. Client submits wizard parameters via `setup-wizard` method
4. Server validates parameters, generates configuration from template, and applies it
5. Server updates settings file to mark device as configured
6. Server sends success response and `login-required` event
7. Device transitions to normal operation mode

### config-load

Loads the active configuration from the system.

**Request:**
```json
{"jsonrpc": "2.0", "method": "config-load", "params": null, "id": 3}
```

**Success Response:**
```json
{"jsonrpc": "2.0", "result": {"unit": {"hostname": "ap"}, "radios": {}, "interfaces": {}}, "id": 3}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 3}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Internal error"}, "id": 3}
```

### config-save

Saves and applies a new configuration. The configuration is validated before being applied to the system.

**Request:**
```json
{"jsonrpc": "2.0", "method": "config-save", "params": {"config": {"unit": {"hostname": "router"}}}, "id": 4}
```

**Success Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 4}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 4}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 4}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Configuration validation failed", "data": {"exit_code": 1}}, "id": 4}
```

### change-password

Changes the authentication password. The new password must be between 8 and 64 characters.

**Request:**
```json
{"jsonrpc": "2.0", "method": "change-password", "params": {"password": "newsecret123"}, "id": 5}
```

**Success Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 5}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 5}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params", "data": {"reason": "Password must be 8-64 characters"}}, "id": 5}
```

### system-info

Retrieves system information including uptime, load, memory usage, storage capacity, and hardware/software details.

**Request:**
```json
{"jsonrpc": "2.0", "method": "system-info", "params": null, "id": 6}
```

**Success Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "uptime": 5302,
    "localtime": 1762860870,
    "load": [160, 32, 0],
    "memory": {
      "total": 1034076160,
      "free": 867745792,
      "shared": 622592,
      "buffered": 4096,
      "available": 887521280,
      "cached": 62889984
    },
    "root": {
      "total": 187624,
      "free": 187560,
      "used": 64,
      "avail": 182724
    },
    "tmp": {
      "total": 504920,
      "free": 504312,
      "used": 608,
      "avail": 504312
    },
    "swap": {
      "total": 0,
      "free": 0
    },
    "kernel": "6.12.57",
    "hostname": "ap",
    "system": "ARMv8 Processor rev 4",
    "model": "OpenWrt One",
    "board_name": "openwrt,one",
    "rootfs_type": "squashfs",
    "release": {
      "distribution": "OpenWrt",
      "version": "SNAPSHOT",
      "firmware_url": "https://downloads.openwrt.org/",
      "revision": "r31749+9-d97e529f1f",
      "target": "mediatek/filogic",
      "description": "OpenWrt SNAPSHOT r31749+9-d97e529f1f",
      "builddate": "1762761837"
    }
  },
  "id": 6
}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 6}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to retrieve system information"}, "id": 6}
```

### devices

Manages device discovery and persistence with four actions: listing devices, setting custom names, configuring ignore flag, and deleting devices.

**List Request:**
```json
{"jsonrpc": "2.0", "method": "devices", "params": {"action": "list"}, "id": 7}
```

**List Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "main": {
      "8e:c2:5a:11:3d:d7": {
        "mac": "8e:c2:5a:11:3d:d7",
        "ipv4": "192.168.1.100",
        "ipv6": ["fe80::8cc2:5aff:fe11:3dd7"],
        "online": true,
        "wifi": {
          "signal": -45,
          "rssi": -45,
          "ifname": "phy1-ap0",
          "ssid": "OpenWrt"
        },
        "dhcp": "dynamic",
        "hostname": "laptop",
        "fingerprint": {
          "device_name": "Dell Laptop",
          "os": "Linux"
        },
        "bytes": 1234567,
        "traffic": {
          "http": { "bytes": 500000 },
          "https": { "bytes": 734567 }
        },
        "created": 1234567890,
        "ignore": false,
        "name": "My Laptop"
      }
    },
    "guest": {}
  },
  "id": 7
}
```

**Set Name Request:**
```json
{"jsonrpc": "2.0", "method": "devices", "params": {"action": "set-name", "mac": "8e:c2:5a:11:3d:d7", "name": "Living Room Laptop"}, "id": 8}
```

**Set Name Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 8}
```

**Clear Name Request (empty string):**
```json
{"jsonrpc": "2.0", "method": "devices", "params": {"action": "set-name", "mac": "8e:c2:5a:11:3d:d7", "name": ""}, "id": 9}
```

**Set Ignore Request:**
```json
{"jsonrpc": "2.0", "method": "devices", "params": {"action": "ignore", "mac": "8e:c2:5a:11:3d:d7", "ignore": true}, "id": 10}
```

**Set Ignore Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 10}
```

**Delete Request:**
```json
{"jsonrpc": "2.0", "method": "devices", "params": {"action": "delete", "mac": "8e:c2:5a:11:3d:d7"}, "id": 11}
```

**Delete Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 11}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 7}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 7}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid action"}, "id": 7}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to retrieve device information"}, "id": 7}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Missing MAC address"}, "id": 8}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Device not found"}, "id": 8}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to set device name"}, "id": 8}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to set ignore flag"}, "id": 10}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to delete device"}, "id": 11}
```

**Actions:**
- `list`: Retrieves information about all discovered devices on the network, grouped by network (main/guest) with connection details, WiFi information, traffic statistics, and device fingerprinting data
- `set-name`: Sets or clears a custom name for a device identified by MAC address. Use empty string to clear the name
- `ignore`: Sets or clears the ignore flag for a device. Ignored devices can be filtered in the UI
- `delete`: Removes a device from the persistent database. The device will be rediscovered if it reconnects to the network

**Device Fields:**
- `mac`: Device MAC address (lowercase)
- `ipv4`: IPv4 address (if assigned)
- `ipv6`: Array of IPv6 addresses
- `online`: Boolean indicating if device is currently reachable
- `wifi`: WiFi connection details (signal strength, interface, SSID)
- `dhcp`: DHCP lease type ("dynamic")
- `hostname`: Device hostname from DHCP or fingerprinting
- `fingerprint`: Device fingerprinting data
- `bytes`: Total network traffic in bytes
- `traffic`: Traffic breakdown by protocol
- `created`: Unix timestamp when device was first seen
- `ignore`: Boolean flag to ignore device in UI
- `name`: User-assigned device name

### radios

Retrieves information about available WiFi radios grouped by band, including valid channels for each supported bandwidth.

**Request:**
```json
{"jsonrpc": "2.0", "method": "radios", "params": null, "id": 8}
```

**Success Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "2G": {
      "channels": {
        "20": ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"],
        "40": ["1", "9"]
      }
    },
    "5G": {
      "channels": {
        "20": ["36", "40", "44", "48", "52", "56", "60", "64", "100", "104", "108", "112", "116", "120", "124", "128", "132", "136", "140", "144", "149", "153", "157", "161", "165"],
        "40": ["36", "44", "52", "60", "100", "108", "116", "124", "132", "140", "149", "157"],
        "80": ["36", "52", "100", "116", "132", "149"],
        "160": ["36", "100"]
      }
    }
  },
  "id": 8
}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 8}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to retrieve radio information"}, "id": 8}
```

**Channel Structure:**
- Radios are grouped by band key: `"2G"`, `"5G"`, `"6G"`
- Each band contains a `channels` object with bandwidth keys: `"20"`, `"40"`, `"80"`, `"160"`, `"320"`
- Each bandwidth array contains valid primary channel numbers for that bandwidth
- Channel lists are filtered based on regulatory domain and hardware capabilities
- All channels in the `"20"` array are available for 20MHz operation
- Higher bandwidth arrays contain only channels valid as primary channels for that bandwidth

### traffic

Retrieves WAN traffic statistics with multi-resolution time-series data for bandwidth graphs. Traffic deltas are tracked at four resolutions: 10-second (real-time), 1-minute, 1-hour, and 1-day intervals.

**Request:**
```json
{"jsonrpc": "2.0", "method": "traffic", "params": null, "id": 9}
```

**Success Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "upload": [
      [1024, 2048, 1536, 2560, 3072, 2048, 1024, 512, 768, 1280, 1792, 2304],
      [61440, 122880, 92160, 153600, 184320, 122880, 61440, 30720, 46080, 76800, 107520, 138240, ...],
      [3686400, 7372800, 5529600, 9216000, 11059200, 7372800, 3686400, 1843200, 2764800, 4608000, ...],
      [88473600, 176947200, 132710400, 221184000, 265420800, 176947200, 88473600]
    ],
    "download": [
      [2048, 4096, 3072, 5120, 6144, 4096, 2048, 1024, 1536, 2560, 3584, 4608],
      [122880, 245760, 184320, 307200, 368640, 245760, 122880, 61440, 92160, 153600, 215040, 276480, ...],
      [7372800, 14745600, 11059200, 18432000, 22118400, 14745600, 7372800, 3686400, 5529600, 9216000, ...],
      [176947200, 353894400, 265420800, 442368000, 530841600, 353894400, 176947200]
    ]
  },
  "id": 9
}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 9}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to retrieve traffic information"}, "id": 9}
```

**Response Structure:**
- `upload`: Array of 4 resolution levels, each containing upload byte deltas
- `download`: Array of 4 resolution levels, each containing download byte deltas

**Resolution Levels:**
1. **Index 0** (Real-time): 12 data points × 10-second intervals ≈ 2 minutes
   - Updates every 10 seconds
   - Most recent data for live monitoring
2. **Index 1** (Hourly view): 60 data points × 1-minute intervals = 60 minutes
   - Updates at minute boundaries (when gmtime().min changes)
3. **Index 2** (Daily view): 24 data points × 1-hour intervals = 24 hours
   - Updates at hour boundaries (when gmtime().hour changes)
4. **Index 3** (Weekly view): 7 data points × 1-day intervals = 7 days
   - Updates at day boundaries (when gmtime().wday changes)

**Data Format:**
- Each array contains incremental byte deltas (not cumulative totals)
- Arrays maintain fixed length via ring buffer (newest value pushes, oldest shifts out)
- All values represent bytes transferred during that time interval
- Use these deltas to calculate bandwidth: `bytes_per_interval / interval_seconds`

**Example Bandwidth Calculation:**
```javascript
// For 10-second resolution (index 0)
let bytes_in_10s = result.upload[0][11];  // Most recent value
let bits_per_second = (bytes_in_10s * 8) / 10;
let mbps = bits_per_second / 1000000;
```

### status

Retrieves system status information including internet connectivity, ethernet port status, connected clients, and WiFi network status.

**Request:**
```json
{"jsonrpc": "2.0", "method": "status", "params": null, "id": 9}
```

**Success Response (Single Port):**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "connectivity": {
      "gateway": "192.168.42.1",
      "ipv4": "192.168.42.20",
      "online_since": 1762885000
    },
    "ports": {
      "wan": [
        {
          "label": "WAN",
          "device": "eth0",
          "link": true,
          "speed": 1000
        }
      ],
      "lan": [
        {
          "label": "LAN",
          "device": "eth1",
          "link": false,
          "speed": null
        }
      ]
    },
    "clients": {
      "main": {
        "online": 5,
        "total": 8
      },
      "guest": {
        "online": 2,
        "total": 3
      }
    },
    "wifi": {
      "main": [
        {
          "ssid": "OpenWrt",
          "enabled": true,
          "clients": 3
        }
      ],
      "guest": [
        {
          "ssid": "Guest",
          "enabled": true,
          "clients": 1
        }
      ]
    }
  },
  "id": 9
}
```

**Success Response (Multiple Ports):**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "connectivity": {
      "gateway": "192.168.42.1",
      "ipv4": "192.168.42.20",
      "online_since": 1762885000
    },
    "ports": {
      "wan": [
        {
          "label": "WAN",
          "device": "eth1",
          "link": true,
          "speed": 1000
        }
      ],
      "lan": [
        {
          "label": "LAN1",
          "device": "lan1",
          "link": false,
          "speed": null
        },
        {
          "label": "LAN2",
          "device": "lan2",
          "link": true,
          "speed": 1000
        },
        {
          "label": "LAN3",
          "device": "lan3",
          "link": false,
          "speed": null
        },
        {
          "label": "LAN4",
          "device": "lan4",
          "link": true,
          "speed": 1000
        }
      ]
    },
    "clients": {
      "main": {
        "online": 5,
        "total": 8
      },
      "guest": {
        "online": 2,
        "total": 3
      }
    },
    "wifi": {
      "main": [
        {
          "ssid": "OpenWrt",
          "enabled": true,
          "clients": 3
        }
      ],
      "guest": [
        {
          "ssid": "Guest",
          "enabled": true,
          "clients": 1
        }
      ]
    }
  },
  "id": 9
}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 9}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to retrieve status information"}, "id": 9}
```

**Status Structure:**
- `connectivity`: Internet connection status
  - `gateway`: Default gateway IP address
  - `ipv4`: Device's IPv4 address
  - `online_since`: Unix timestamp when connection was established
- `ports`: Ethernet port status from board.json
  - Port groups (e.g., `wan`, `lan`) each containing an array of port objects
  - Each port object contains:
    - `label`: Human-readable port label (e.g., "WAN", "LAN" for single ports, or "WAN1", "LAN1", "LAN2" for multiple ports)
    - `device`: Network device name (e.g., "eth0", "lan1")
    - `link`: Boolean indicating if physical link is up
    - `speed`: Link speed in Mbps (null if link is down)
- `clients`: Connected client counts per network
  - `online`: Number of currently online clients
  - `total`: Total number of known clients
- `wifi`: WiFi network status per network
  - Array of SSIDs with enabled state and aggregated client count across all radios

### tailscale

Manages Tailscale VPN integration with two actions: checking status and initiating login.

**Status Request:**
```json
{"jsonrpc": "2.0", "method": "tailscale", "params": {"action": "status"}, "id": 10}
```

**Status Response (NeedsLogin):**
```json
{"jsonrpc": "2.0", "result": {"BackendState": "NeedsLogin"}, "id": 10}
```

**Status Response (Running):**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "BackendState": "Running",
    "TailscaleIPs": ["100.x.x.x", "fd7a:115c:a1e0::xxxx:xxxx"],
    "HostName": "device-name",
    "DNSName": "device-name.example.ts.net.",
    "Online": true,
    "Uptime": 1800,
    "RxBytes": 12345,
    "TxBytes": 67890,
    "Peers": [
      {
        "HostName": "peer-device",
        "DNSName": "peer-device.example.ts.net.",
        "TailscaleIPs": ["100.y.y.y", "fd7a:115c:a1e0::yyyy:yyyy"],
        "Online": true,
        "LastSeen": "2025-11-12T16:30:00Z",
        "RxBytes": 54321,
        "TxBytes": 98765,
        "OS": "linux"
      }
    ]
  },
  "id": 10}
```

**Login Request:**
```json
{"jsonrpc": "2.0", "method": "tailscale", "params": {"action": "login"}, "id": 11}
```

**Login Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "AuthURL": "https://login.tailscale.com/a/72c912d01d04e",
    "QR": "data:image/png;base64,iVBORw0KGgo...",
    "BackendState": "NeedsLogin"
  },
  "id": 11
}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 10}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 10}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Tailscale service is not running"}, "id": 10}
```

**Start Request:**
```json
{"jsonrpc": "2.0", "method": "tailscale", "params": {"action": "start"}, "id": 12}
```

**Start Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 12}
```

**Start Error (Already Running):**
```json
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Tailscale is already running"}, "id": 12}
```

**Stop Request:**
```json
{"jsonrpc": "2.0", "method": "tailscale", "params": {"action": "stop"}, "id": 13}
```

**Stop Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 13}
```

**Stop Error (Already Stopped):**
```json
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Tailscale is already stopped"}, "id": 13}
```

**Actions:**
- `status`: Checks if Tailscale service is running and returns connection status. When `BackendState` is `"Running"`, includes detailed information about the device and connected peers
- `login`: Initiates Tailscale authentication and returns the `AuthURL` for user to visit, along with a QR code for mobile scanning
- `start`: Brings up the Tailscale tunnel. Checks current state first and returns error if already running
- `stop`: Brings down the Tailscale tunnel. Checks current state first and returns error if already stopped

**Status Response Fields:**
- `BackendState`: Current state of Tailscale (e.g., "NeedsLogin", "Running")

When `BackendState` is `"Running"`, additional fields are included:
- `TailscaleIPs`: Array of Tailscale IP addresses (IPv4 and IPv6) assigned to this device
- `HostName`: Device hostname
- `DNSName`: Fully qualified domain name in the tailnet
- `Online`: Boolean indicating if device is online
- `Uptime`: Seconds since device joined the tailnet (calculated from Created timestamp)
- `RxBytes`: Total bytes received
- `TxBytes`: Total bytes transmitted
- `Peers`: Array of peer devices in the tailnet, each containing:
  - `HostName`: Peer hostname
  - `DNSName`: Peer fully qualified domain name
  - `TailscaleIPs`: Array of peer's Tailscale IPs
  - `Online`: Boolean indicating if peer is currently online
  - `LastSeen`: ISO 8601 timestamp of last contact
  - `RxBytes`: Bytes received from this peer
  - `TxBytes`: Bytes transmitted to this peer
  - `OS`: Operating system of peer device

**Login Response Fields:**
- `AuthURL`: URL for user to authenticate with Tailscale
- `QR`: Base64-encoded PNG QR code for mobile authentication
- `BackendState`: Current state (typically "NeedsLogin")

### storage

Manages block device (USB/NVMe) storage with three actions: listing devices, toggling UCI mount configuration, and system-wide mount/unmount operations.

**List Request:**
```json
{"jsonrpc": "2.0", "method": "storage", "params": {"action": "list"}, "id": 10}
```

**List Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "devices": [
      {
        "name": "sda1",
        "device": "/dev/sda1",
        "type": "vfat",
        "uuid": "72F1-11E7",
        "label": "FOO",
        "version": "FAT32",
        "size_bytes": 32212254720,
        "size_human": "30.0 GB",
        "mounted": false,
        "mount_point": null,
        "model": "USB Flash Drive",
        "removable": true,
        "configured": false,
        "config_target": "/mnt/sda1",
        "config_enabled": false
      },
      {
        "name": "nvme0n1",
        "device": "/dev/nvme0n1",
        "type": "ext4",
        "uuid": "abc-def-123",
        "label": "DATA",
        "version": null,
        "size_bytes": 1024209543168,
        "size_human": "953.9 GB",
        "mounted": true,
        "mount_point": "/mnt/data",
        "model": "WD PC SN810 SDCQNRY-1T00-1001",
        "removable": false,
        "configured": true,
        "config_target": "/mnt/data",
        "config_enabled": true
      }
    ]
  },
  "id": 10
}
```

**Toggle Request:**
```json
{"jsonrpc": "2.0", "method": "storage", "params": {"action": "toggle", "device": "sda1"}, "id": 11}
```

**Toggle Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 11}
```

**Mount Request:**
```json
{"jsonrpc": "2.0", "method": "storage", "params": {"action": "mount"}, "id": 12}
```

**Mount Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 12}
```

**Unmount Request:**
```json
{"jsonrpc": "2.0", "method": "storage", "params": {"action": "umount"}, "id": 13}
```

**Unmount Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 13}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 10}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 10}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid action"}, "id": 10}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Missing device parameter"}, "id": 11}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to retrieve block device information"}, "id": 10}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Device not found"}, "id": 11}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Device has no UUID or label"}, "id": 11}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to mount devices"}, "id": 12}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Failed to unmount devices"}, "id": 13}
```

**Actions:**
- `list`: Retrieves information about all block devices detected by blockd, enriched with sysfs data (size, model, removable status) and UCI configuration status
- `toggle`: Toggles the `enabled` field in UCI fstab for a device. If no UCI entry exists, creates one with UUID-based identification, `enabled='1'`, and default target `/mnt/<device>`
- `mount`: Executes system-wide `block mount` to mount all enabled devices
- `umount`: Executes system-wide `block umount` to unmount all devices

**Device Fields:**
- `name`: Device name (e.g., "sda1", "nvme0n1")
- `device`: Full device path (e.g., "/dev/sda1")
- `type`: Filesystem type (e.g., "vfat", "ext4", "ntfs")
- `uuid`: Device UUID (null if not available)
- `label`: Device label (null if not set)
- `version`: Filesystem version (e.g., "FAT32")
- `size_bytes`: Device size in bytes (null if unavailable)
- `size_human`: Human-readable size (e.g., "30.0 GB", "953.9 GB")
- `mounted`: Boolean indicating if device is currently mounted
- `mount_point`: Current mount point path (null if not mounted)
- `model`: Device model name from sysfs (null if unavailable)
- `removable`: Boolean indicating if device is removable (e.g., USB)
- `configured`: Boolean indicating if device has UCI mount configuration
- `config_target`: Mount point from UCI configuration or default `/mnt/<device>`
- `config_enabled`: Boolean indicating if UCI mount is enabled

**Workflow:**
1. User sees list of storage devices with current mount status and UCI configuration
2. User toggles enabled on/off for devices (updates UCI, commits immediately)
3. User clicks mount button to mount all enabled devices system-wide
4. User clicks unmount button to unmount all devices system-wide

**Notes:**
- System filesystems (ubifs, squashfs) and system mount points (/rom, /overlay) are filtered out to only show removable/user storage
- Device size is calculated from `/sys/block/<dev>/size` × `/sys/block/<dev>/queue/logical_block_size`
- Device model is read from `/sys/block/<dev>/device/model` for NVMe/SCSI devices
- UCI configurations use UUID for device identification (falls back to label if no UUID)
- Toggle operation flips between enabled='0' and enabled='1' in UCI
- Mount/unmount operations are system-wide, not per-device

### usnitch

Manages network access control rules with actions for listing rules, managing device policies, and responding to blocked connection notifications.

**List Request:**
```json
{"jsonrpc": "2.0", "method": "usnitch", "params": {"action": "list"}, "id": 14}
```

**List Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "rules": [
      {
        "mac": "aa:bb:cc:dd:ee:ff",
        "ip": "192.0.2.1",
        "port": 443,
        "proto": "tcp",
        "allow": true,
        "expires": 0
      }
    ],
    "devices": {
      "aa:bb:cc:dd:ee:ff": { "allow": false }
    },
    "global_rules": [
      { "port": 53, "proto": "udp", "allow": true }
    ],
    "device_port_rules": [
      {
        "mac": "aa:bb:cc:dd:ee:ff",
        "port": 443,
        "proto": "tcp",
        "allow": true
      }
    ]
  },
  "id": 14
}
```

**Device Add Request:**
```json
{"jsonrpc": "2.0", "method": "usnitch", "params": {"action": "device_add", "mac": "aa:bb:cc:dd:ee:ff", "allow": false}, "id": 15}
```

**Device Add Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 15}
```

**Device Delete Request:**
```json
{"jsonrpc": "2.0", "method": "usnitch", "params": {"action": "device_delete", "mac": "aa:bb:cc:dd:ee:ff"}, "id": 16}
```

**Device Delete Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 16}
```

**Rule Add Request (IP-based):**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "rule_add",
    "mac": "aa:bb:cc:dd:ee:ff",
    "ip": "192.0.2.1",
    "port": 443,
    "proto": "tcp",
    "allow": true,
    "expires": 0
  },
  "id": 17
}
```

**Rule Add Request (FQDN-based):**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "rule_add",
    "mac": "aa:bb:cc:dd:ee:ff",
    "fqdn": "*.example.com",
    "port": 443,
    "proto": "tcp",
    "allow": true
  },
  "id": 18
}
```

**Rule Add Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 17}
```

**Rule Delete Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "rule_delete",
    "mac": "aa:bb:cc:dd:ee:ff",
    "ip": "192.0.2.1",
    "port": 443,
    "proto": "tcp"
  },
  "id": 19
}
```

**Rule Delete Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 19}
```

**Global Rule Add Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "global_rule_add",
    "port": 53,
    "proto": "udp",
    "allow": true
  },
  "id": 20
}
```

**Global Rule Add Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 20}
```

**Global Rule Delete Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "global_rule_delete",
    "port": 53,
    "proto": "udp"
  },
  "id": 21
}
```

**Global Rule Delete Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 21}
```

**Device Port Rule Add Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "device_port_rule_add",
    "mac": "aa:bb:cc:dd:ee:ff",
    "port": 443,
    "proto": "tcp",
    "allow": true
  },
  "id": 22
}
```

**Device Port Rule Add Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 22}
```

**Device Port Rule Delete Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "device_port_rule_delete",
    "mac": "aa:bb:cc:dd:ee:ff",
    "port": 443,
    "proto": "tcp"
  },
  "id": 23
}
```

**Device Port Rule Delete Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 23}
```

**Respond to Notification Request (Temporary Allow):**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "respond",
    "notification_id": 0,
    "action_type": 1,
    "timeout": 120
  },
  "id": 24
}
```

**Respond to Notification Request (Permanent Allow):**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "respond",
    "notification_id": 0,
    "action_type": 2
  },
  "id": 25
}
```

**Respond to Notification Request (Wildcard Domain Allow):**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch",
  "params": {
    "action": "respond",
    "notification_id": 0,
    "action_type": 3
  },
  "id": 26
}
```

**Respond Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 24}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 14}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 14}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid action"}, "id": 14}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Missing MAC address"}, "id": 15}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Missing port"}, "id": 20}
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Notification not found or already responded"}, "id": 24}
```

**Actions:**
- `list`: Retrieves all network access control rules including exact IP rules, device default policies, global port rules, and device-specific port rules
- `device_add`: Sets default policy for a device (allow=true for blocklist mode, allow=false for allowlist mode)
- `device_delete`: Removes device default policy
- `rule_add`: Creates exact match rule for device to specific IP or FQDN on port/protocol. Supports wildcard domains (e.g., "*.example.com")
- `rule_delete`: Removes exact IP rule
- `global_rule_add`: Creates global port/protocol rule applying to all devices
- `global_rule_delete`: Removes global port rule
- `device_port_rule_add`: Creates device-specific port/protocol rule (any destination IP)
- `device_port_rule_delete`: Removes device port rule
- `respond`: Responds to blocked connection notification with action type (1=temporary, 2=permanent, 3=wildcard domain)

**Rule Types and Precedence:**
1. Global Port Rules - Allow/block all devices on specific port/protocol
2. Exact IP Rules - Most specific match (device + destination + port + protocol)
3. Device Port Rules - Device-specific port/protocol rules (any destination)
4. Device Default - Per-device allow/block policy
5. Final Default - Block if no rules match

**Response Action Types:**
- `1` (Temporary Allow): Creates temporary exact IP rule that expires after timeout seconds (default 120)
- `2` (Permanent Allow): Creates permanent FQDN rule if domain available, otherwise creates permanent IP rule
- `3` (Wildcard Domain Allow): Creates permanent wildcard FQDN rule (e.g., `*.example.com`), falls back to action 2 if no domain available

**Rule Fields:**
- `mac`: Device MAC address
- `ip`: Destination IPv4 or IPv6 address (mutually exclusive with fqdn)
- `fqdn`: Domain name with optional wildcard prefix (e.g., "*.example.com")
- `port`: Destination port (0-65535)
- `proto`: Protocol ("tcp" or "udp")
- `allow`: Boolean (true=allow, false=block)
- `expires`: Unix timestamp for temporary rules (0=permanent)

**Workflow:**
1. usnitch daemon detects blocked connection and sends notification event
2. Client receives `usnitch-blocked` event and displays approval dialog
3. User chooses action (temporary, permanent, wildcard, or block)
4. Client sends `respond` action with notification_id and action_type
5. Daemon creates appropriate rule based on action type
6. Future matching connections are handled according to new rule

### reboot

Reboots the system. The server sends a success response, broadcasts a "rebooting" event to all connected clients, closes all connections, then reboots after 2 seconds.

**Request:**
```json
{"jsonrpc": "2.0", "method": "reboot", "params": null, "id": 12}
```

**Success Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 12}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 12}
```

### factory-reset

Performs a factory reset and reboots the system. The server sends a success response, broadcasts a "factory-reset" event to all connected clients, closes all connections, then executes factory reset after 2 seconds.

**Request:**
```json
{"jsonrpc": "2.0", "method": "factory-reset", "params": null, "id": 13}
```

**Success Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 13}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 13}
```

### sysupgrade

System firmware upgrade in two steps: token generation and application.

**Token Request:**
```json
{"jsonrpc": "2.0", "method": "sysupgrade", "params": {"action": "token"}, "id": 14}
```

**Token Response:**
```json
{"jsonrpc": "2.0", "result": {"token": "uuid", "upload_url": "/upload/uuid", "max_size": 52428800, "expires_in": 600}, "id": 14}
```

**Apply Request:**
```json
{"jsonrpc": "2.0", "method": "sysupgrade", "params": {"action": "apply", "file_id": "uuid", "keep_config": true}, "id": 15}
```

**Apply Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 15}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 14}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 14}
```

### config-restore

Configuration restore in two steps: token generation and application.

**Token Request:**
```json
{"jsonrpc": "2.0", "method": "config-restore", "params": {"action": "token"}, "id": 16}
```

**Token Response:**
```json
{"jsonrpc": "2.0", "result": {"token": "uuid", "upload_url": "/upload/uuid", "max_size": 10485760, "expires_in": 600}, "id": 16}
```

**Apply Request:**
```json
{"jsonrpc": "2.0", "method": "config-restore", "params": {"action": "apply", "file_id": "uuid"}, "id": 17}
```

**Apply Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 17}
```

**Error Responses:**
```json
{"jsonrpc": "2.0", "error": {"code": -32001, "message": "login-required"}, "id": 16}
{"jsonrpc": "2.0", "error": {"code": -32602, "message": "Invalid params"}, "id": 16}
```

## 5. Events

Events are server-initiated notifications sent to clients. They use JSON-RPC 2.0 notification format (no `id` field).

### setup-required

Sent to a client 200ms after the WebSocket connection is established when the device has not been configured. This event indicates that the client must complete the setup wizard before any other operations. While in setup mode, all methods except `setup-wizard` are blocked.

**Event:**
```json
{"jsonrpc": "2.0", "method": "setup-required"}
```

### login-required

Sent to a client 200ms after the WebSocket connection is established when the device is configured, or sent after successful completion of the setup wizard. This event notifies the client that authentication is required before invoking protected methods.

**Event:**
```json
{"jsonrpc": "2.0", "method": "login-required"}
```

### rebooting

Sent to all connected clients when the system is about to reboot. The connection is closed immediately after this event is sent.

**Event:**
```json
{"jsonrpc": "2.0", "method": "rebooting"}
```

### factory-reset

Sent to all connected clients when the system is about to perform a factory reset. The connection is closed immediately after this event is sent.

**Event:**
```json
{"jsonrpc": "2.0", "method": "factory-reset"}
```

### sysupgrade-validation-success

Sent to all connected clients when an uploaded firmware file passes validation.

**Event:**
```json
{"jsonrpc": "2.0", "method": "sysupgrade-validation-success", "params": {"file_id": "uuid"}}
```

### sysupgrade-validation-failed

Sent to all connected clients when an uploaded firmware file fails validation.

**Event:**
```json
{"jsonrpc": "2.0", "method": "sysupgrade-validation-failed", "params": {"error": "Firmware validation failed"}}
```

### upgrading

Sent to all connected clients when the system is about to perform a firmware upgrade. The connection is closed immediately after this event is sent.

**Event:**
```json
{"jsonrpc": "2.0", "method": "upgrading"}
```

### config-restore-validation-success

Sent to all connected clients when an uploaded configuration file passes validation.

**Event:**
```json
{"jsonrpc": "2.0", "method": "config-restore-validation-success", "params": {"file_id": "uuid"}}
```

### config-restore-validation-failed

Sent to all connected clients when an uploaded configuration file fails validation.

**Event:**
```json
{"jsonrpc": "2.0", "method": "config-restore-validation-failed", "params": {"error": "Invalid JSON format"}}
```

### config-restore

Sent to all connected clients when the system is about to restore configuration. The connection is closed immediately after this event is sent.

**Event:**
```json
{"jsonrpc": "2.0", "method": "config-restore"}
```

### config-apply-start

Sent to all connected clients when a configuration has passed validation and is about to be applied to the system. This indicates the apply phase has started.

**Event:**
```json
{"jsonrpc": "2.0", "method": "config-apply-start"}
```

### config-apply-success

Sent to all connected clients when a configuration has been successfully applied to the system.

**Event:**
```json
{"jsonrpc": "2.0", "method": "config-apply-success"}
```

### config-apply-failed

Sent to all connected clients when a configuration validation or apply operation fails. This event includes error details and the exit code from the failed operation.

**Event:**
```json
{"jsonrpc": "2.0", "method": "config-apply-failed", "params": {"error": "Configuration validation failed", "exit_code": 1}}
```

### usnitch-blocked

Sent to all connected clients when the usnitch daemon blocks a network connection. Clients should display an approval dialog to allow the user to respond with an action (temporary allow, permanent allow, wildcard domain allow, or block).

**Event:**
```json
{
  "jsonrpc": "2.0",
  "method": "usnitch-blocked",
  "params": {
    "notification_id": 0,
    "mac": "aa:bb:cc:dd:ee:ff",
    "ip": "192.0.2.1",
    "port": 443,
    "proto": "tcp",
    "timestamp": 1735849200,
    "domain": "example.com"
  }
}
```

**Parameters:**
- `notification_id`: Unique identifier for this notification (required for responding)
- `mac`: Device MAC address that attempted the connection
- `ip`: Destination IP address (IPv4 or IPv6)
- `port`: Destination port number
- `proto`: Protocol ("tcp" or "udp")
- `timestamp`: Unix timestamp when connection was blocked
- `domain`: Domain name if available from DNS cache (optional)

**Workflow:**
1. Daemon sends event to all connected clients
2. Client displays approval dialog with options:
   - Allow Once (temporary with timeout)
   - Always Allow (permanent)
   - Allow *.domain (wildcard domain, if domain is available)
   - Block (no action required, connection stays blocked)
3. Client responds using `usnitch` method with `respond` action and the `notification_id`
4. Daemon creates appropriate rule based on response action type

## 6. HTTP Upload

File uploads are performed via HTTP PUT requests to the upload URL provided in the token response.

**Upload Request:**
```
PUT /upload/{token} HTTP/1.1
Content-Length: 12345678
X-Filename: firmware.bin (optional)

<binary file data>
```

**Upload Success Response:**
```json
{
  "token": "uuid",
  "file_id": "uuid",
  "file_path": "/tmp/sysupgrade.123456",
  "filesize": 12345678,
  "upload_duration": 5,
  "token_type": "sysupgrade",
  "status": "upload_complete"
}
```

**Upload Failure Response:**
```json
{
  "status": "validation_failed",
  "error": "Firmware validation failed (exit code: 1)"
}
```

**Notes:**
- Tokens expire after 10 minutes
- Each token can only be used once
- Maximum file size: 50MB for sysupgrade, 10MB for config-restore
- Files are automatically validated after upload
- Failed uploads are automatically deleted
