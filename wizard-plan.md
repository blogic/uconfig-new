# uconfig-wizard Extension Plan

Source: `files/usr/bin/uconfig-wizard`

## Module detection

Installed modules are discovered by reading sentinel files from
`/etc/uconfig/modules/`. The wizard checks for the presence of these
files to decide which optional prompts to show:

| Sentinel file | Gates prompt for |
|---------------|------------------|
| `wwan` | WWAN option in WAN type selection |
| `batman-adv` | Mesh backhaul question |
| `mdns` | mDNS service question |
| `lldp` | LLDP service question |
| `qosify` | QoS question |

Detection uses `access('/etc/uconfig/modules/<name>')` or equivalent
filesystem check at startup, stored in a lookup table for use throughout
the wizard flow.

---

## Wizard flow

### Step 1 -- Device mode (existing, unchanged)

```
Device mode
  [1] Access Point (all ports bridged, DHCP client)
  [2] Router (WAN + LAN, NAT, DHCP server)
Choice [1-2]:
```

### Step 2 -- WAN connection type (NEW, Router mode only)

Only shown when `mode_idx == 1` (Router). Option 3 only appears when
the `wwan` module is installed **and** `mmcli -m 0` detects a modem.
The modem's sysfs device path is extracted automatically from mmcli
output and stored in the config.

```
WAN connection type
  [1] Ethernet
  [2] PPPoE
  [3] WWAN (5G/LTE)            <-- only if modem detected
Choice [1-3]:
```

#### Step 2a -- PPPoE credentials (if PPPoE chosen)

```
PPPoE username: user1
PPPoE password: ********
PPPoE VLAN ID (leave blank if none): 7
```

The VLAN ID is optional. When provided, a `vlan` section is added to
the `wan` interface. When left blank, no VLAN tagging is used.

Produces on the `wan` interface (replaces the `ipv4`/`ipv6` sections):

```json
"vlan": {
    "id": 7
},
"broad-band": {
    "type": "pppoe",
    "username": "user1",
    "password": "password1"
}
```

The `vlan` block is omitted entirely when the user leaves the VLAN ID
blank.

Reference: `files/etc/uconfig/examples/pppoe.json`

#### Step 2b -- WWAN settings (if WWAN chosen)

```
APN: internet.telekom
Username (leave blank if none): telekom
Password (leave blank if none): ********
SIM PIN code (leave blank if none): 9360
```

The modem device path is auto-detected via `mmcli -m 0` and not
prompted. IP type defaults to `ipv4v6`. All fields except APN are
optional. Omitted fields are left out of the config entirely. The
`wan` interface has no `ports` section for WWAN (no physical ethernet
port is used).

Produces on the `wan` interface (replaces `ports` and `ipv4`/`ipv6`):

```json
"broad-band": {
    "type": "wwan",
    "device": "/sys/devices/platform/soc/11200000.usb/usb1/1-1/1-1.2",
    "apn": "internet.telekom",
    "ip-type": "ipv4v6",
    "username": "telekom",
    "password": "tm",
    "pincode": "9360"
}
```

Fields `username`, `password`, and `pincode` are each omitted when the
user leaves them blank.

Reference: `files/etc/uconfig/examples/wwan.json`

### Step 3 -- Root password (existing, unchanged)

```
Set root password? [Y/n]:
Password: ********
```

### Step 4 -- Hostname (existing, unchanged)

```
Hostname [OpenWrt]:
```

### Step 5 -- Timezone (existing, unchanged)

Region and city selection -- unchanged.

### Step 6 -- Wireless (existing, unchanged)

SSID, security mode, and key -- unchanged.

### Step 7 -- Batman-adv mesh backhaul (NEW, conditional)

Only shown when **all** of these hold:
- `batman-adv` module is installed
- At least one radio is available (5G or 2G)
- WAN type is **Ethernet** (Router mode) **or** device is in **AP mode**

Not offered for PPPoE/WWAN because those modes already consume the WAN
uplink differently.

The mesh radio is selected automatically: 5G if available, otherwise 2G.
If neither radio was discovered, the batman-adv prompt is skipped
entirely.

```
Enable batman-adv mesh backhaul? [y/N]:
Mesh SSID [mesh]:
Mesh key: ********
```

Adds a mesh SSID alongside the main SSID on the interface that carries
SSIDs (lan in Router mode, wan in AP mode):

```json
"mesh": {
    "ssid": "mesh",
    "wifi-radios": ["5G"],
    "bss-mode": "mesh",
    "template": {
        "mode": "batman-adv",
        "key": "<mesh key>"
    }
}
```

`wifi-radios` is set to `["5G"]` when 5G is available, otherwise
`["2G"]`.

Reference: `files/etc/uconfig/examples/mesh-batman.json`

### Step 8 -- SSH (existing, unchanged)

```
Enable SSH? [Y/n]:
```

### Step 9 -- mDNS (NEW, conditional)

Only shown when the `mdns` module is installed.

```
Enable mDNS? [Y/n]:
```

- **Router mode**: added to `lan.services`
- **AP mode**: added to `wan.services`

### Step 10 -- LLDP (NEW, conditional)

Only shown when the `lldp` module is installed.

```
Enable LLDP? [Y/n]:
```

- **Router mode**: added to `lan.services`
- **AP mode**: added to `wan.services`

### Step 11 -- QoS (NEW, conditional)

Only shown when the `qosify` module is installed.

```
Enable QoS? [Y/n]:
```

When enabled, two things are added to the config:

1. A global `services.quality-of-service` block with bulk detection
   defaults and all service names from `qos.json`:

```json
"services": {
    "quality-of-service": {
        "bulk-detection": {
            "dscp": "CS0",
            "packets-per-second": 500
        },
        "services": [
            "networking", "browsing", "youtube", "netflix",
            "amazon-prime", "disney-plus", "hbo", "rtmp",
            "stun", "zoom", "facetime", "webex", "jitsi",
            "google-meet", "teams", "voip", "vowifi"
        ]
    }
}
```

2. Bandwidth limits on the `wan` interface:

```json
"quality-of-service": {
    "bandwidth-up": 1000,
    "bandwidth-down": 1000
}
```

The `quality-of-service` service name is also added to the services
list on the appropriate interface (lan in Router mode, wan in AP mode).

Reference: `schema/service.quality-of-service.yml`,
`schema/interface.quality-of-service.yml`,
`modules/qosify/usr/share/ucode/uconfig/qos.json`

---

## Configuration summary (extended)

The existing summary block is extended with the new fields:

```
--- Configuration summary ---
  Mode:      Router
  WAN:       PPPoE (user: user1)       <-- new
  Password:  set
  Hostname:  OpenWrt
  Timezone:  Europe/Berlin
  SSID:      OpenWrt
  Security:  compatibility
  Radios:    2G, 5G
  Mesh:      enabled                   <-- new
  SSH:       enabled
  mDNS:      enabled
  LLDP:      enabled                   <-- new
  QoS:       enabled                   <-- new
```

The WAN line shows `Ethernet`, `PPPoE (user: <username>)`, or
`WWAN (apn: <apn>)` depending on the selection. In AP mode the WAN
line is omitted (no WAN type choice).
