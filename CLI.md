# uconfig CLI Reference

This guide covers all commands available in the uconfig CLI for configuring an OpenWrt access point. The CLI provides a hierarchical, interactive interface for managing device settings, network interfaces, wireless radios, and services.

## Getting Started

Launch the CLI:

```
root@ap:~# cli
Welcome to the OpenWrt CLI. Press '?' for help on commands/arguments
cli>
```

Enter the uconfig configuration mode:

```
cli> uconfig
cli uconfig>
```

The prompt always shows the full navigation path. Use Tab for auto-completion at any point. Type ? to see available commands and arguments.

## Top-Level Commands

Once inside the uconfig context, the following commands are available:

| Command | Description |
|---------|-------------|
| enable | Enable uconfig-based UCI generation |
| disable | Disable uconfig-based UCI generation |
| status | Show the active configuration UUID and creation timestamp |
| show | Print the full raw active configuration |
| list | List all stored configurations (marks the active one) |
| state | Display current device state (hardware, radios, ports) |
| rollback \<uuid\> | Roll back to a previously stored configuration |
| dry-run | Test pending changes without applying them |
| edit | Enter the configuration editor |

### Example: Check Status and Roll Back

```
cli uconfig> status
cli uconfig> list
cli uconfig> rollback 1709312400
```

## The Editor

The edit command enters the configuration editor where all device settings are modified. Every editor context supports a standard set of operations:

| Operation | Description |
|-----------|-------------|
| show | Display current values |
| set | Modify one or more parameters |
| add | Append values to list parameters (multi-value fields only) |
| remove | Remove values from list parameters (by value or index) |
| commit | Validate and apply pending changes to the device |

Parameters are passed by name followed by their value. For example:

```
cli uconfig edit unit> set hostname MyAP timezone Europe/Berlin
```

After making changes, always run commit to apply them. If you leave without committing, the CLI warns about unsaved changes.

### Objects: create, list, edit, destroy

Some sections manage named objects (interfaces, SSIDs, RADIUS users, etc.). These provide additional operations:

| Operation | Description |
|-----------|-------------|
| create \<type\> \<name\> [param val ...] | Create a new named object with optional initial values |
| list [type] | List existing objects |
| \<type\> \<name\> or edit \<name\> | Enter the editor for a specific object |
| destroy \<type\> \<name\> | Delete a named object |

---

## Unit (Device Settings)

```
cli uconfig edit> unit
cli uconfig edit unit>
```

Configure device-wide settings.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| hostname | string | | Device hostname |
| timezone | enum | | Timezone (e.g. Europe/London, America/New_York) |
| leds-active | bool | | Enable or disable all LEDs on the device |
| root-password-hash | string | | Password hash for root (as it appears in /etc/shadow) |
| tty-login-required | bool | | Require password for serial console logins |

### Example

```
cli uconfig edit unit> set hostname OfficeAP timezone Europe/London leds-active 1
cli uconfig edit unit> show
cli uconfig edit unit> commit
```

---

## Definitions (Global Settings)

```
cli uconfig edit> definitions
cli uconfig edit definitions>
```

Configure global network ranges and NTP servers.

| Parameter | Type | Description |
|-----------|------|-------------|
| ipv4-network | CIDR4 | IPv4 range delegatable to downstream interfaces (e.g. 192.168.0.0/16) |
| ipv6-network | CIDR6 | IPv6 range delegatable to downstream interfaces |
| ntp-servers | host (list) | Upstream NTP servers |

### Example

```
cli uconfig edit definitions> set ipv4-network 192.168.0.0/16
cli uconfig edit definitions> add ntp-servers pool.ntp.org
cli uconfig edit definitions> show
```

### RADIUS Server Definitions

Within the definitions context, manage named RADIUS server profiles that can be referenced by SSIDs using enterprise authentication.

**Create a RADIUS server definition:**

```
cli uconfig edit definitions> create radius my-radius
cli uconfig edit definitions> radius my-radius
cli uconfig edit definitions radius "my-radius">
```

**RADIUS server definition parameters** (show/set at the server level):

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| nas-identifier | string | | NAS-Identifier string for RADIUS messages |
| chargeable-user-id | bool | false | Enable Chargeable-User-Identity support (RFC 4372) |

**Subcommands within a RADIUS server definition:**

#### authentication

Configure the RADIUS authentication server.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| host | host | *required* | Authentication server address |
| port | int (1024-65535) | 1812 | Authentication port |
| secret | string | secret | Shared RADIUS secret |

#### accounting

Configure the RADIUS accounting server.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| host | host | *required* | Accounting server address |
| port | int (1024-65535) | 1813 | Accounting port |
| secret | string | secret | Shared RADIUS secret |
| interval | int (60-600) | 60 | Interim accounting update interval (seconds) |

#### dynamic-authorization

Configure Dynamic Authorization Extensions (DAE/CoA).

| Parameter | Type | Description |
|-----------|------|-------------|
| host | IPv4 | DAE client IP address |
| port | int (1024-65535) | DAE client port |
| secret | string | Shared DAE secret |

### Example: Full RADIUS Setup

```
cli uconfig edit definitions> create radius enterprise-radius
cli uconfig edit definitions> radius enterprise-radius
cli uconfig edit definitions radius "enterprise-radius"> authentication
cli uconfig edit definitions radius "enterprise-radius" authentication> set host radius.example.com port 1812 secret mysecret
cli uconfig edit definitions radius "enterprise-radius" authentication> commit
```

---

## Ethernet (Physical Port Settings)

```
cli uconfig edit> ethernet "1"
cli uconfig edit ethernet "1">
```

The index is 1-based (first port group = 1).

| Parameter | Type | Description |
|-----------|------|-------------|
| select-ports | string (list) | Port selection patterns (LAN*, WAN*, LAN1, *) |
| speed | enum | Forced link speed: 10, 100, 1000, 2500, 5000, 10000 (Mbps) |
| duplex | enum | Forced duplex mode: half, full |

### Example

```
cli uconfig edit ethernet "1"> set select-ports LAN1 speed 1000 duplex full
cli uconfig edit ethernet "1"> commit
```

---

## Radios (Wireless Radio Configuration)

```
cli uconfig edit> radios "5G"
cli uconfig edit radios "5G">
```

The band argument selects which radio to configure. Available bands depend on the device hardware (e.g. 2G, 5G, 6G).

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| channel-mode | enum | varies | HT mode hint: HT, VHT, HE, EHT |
| channel-width | enum | varies | Channel width in MHz: 20, 40, 80, 160, 320 |
| channel | enum | auto | Channel number or auto for ACS |
| allow-dfs | bool | true | Allow DFS channels (5G only) |
| maximum-clients | int | | Maximum clients across all SSIDs on this radio |
| tx-power | int (0-max) | | Transmit power in dBm |
| legacy-rates | bool | false | Allow 802.11b rates |
| require-mode | enum | | Reject stations below this mode: HT, VHT, HE |
| valid-channels | int (list) | | Restrict ACS to these channels |
| he-multiple-bssid | bool | | Enable multiple BSSID beacon IE (HE/EHT only) |

### rates

```
cli uconfig edit radios "5G"> rates
cli uconfig edit radios "5G" rates>
```

Configure beacon and multicast rates.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| beacon | enum (kbps) | 6000 | Beacon rate |
| multicast | enum (kbps) | 24000 | Multicast rate |

Valid rate values (kbps): 0, 1000, 2000, 5500, 6000, 9000, 11000, 12000, 18000, 24000, 36000, 48000, 54000

### Example

```
cli uconfig edit> radios "5G"
cli uconfig edit radios "5G"> set channel-mode HE channel-width 80 channel auto tx-power 20
cli uconfig edit radios "5G"> rates
cli uconfig edit radios "5G" rates> set beacon 6000 multicast 24000
cli uconfig edit radios "5G" rates> commit
```

---

## Interfaces

Interfaces are the core of network configuration. Each interface groups physical ports, wireless SSIDs, IP addressing, and firewall rules.

### Managing Interfaces

```
cli uconfig edit> list interface
cli uconfig edit> create interface <name> [role upstream|downstream]
cli uconfig edit> interface <name>
cli uconfig edit> destroy interface <name>
```

### Interface Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| role | enum | downstream | upstream (WAN-facing) or downstream (LAN-facing) |
| disable | bool | false | Do not bring up this interface on apply |
| isolate-hosts | bool | false | Guest network mode -- block local IP ranges |
| vlan-id | int (1-4095) | | VLAN ID for this interface |
| vlan-trunks | int (list, 1-4095) | | Upstream VLAN trunks for NAT |
| service | enum (list) | | Services to enable (e.g. ssh, log, radius-server) |
| port | enum (list) | | Physical ports to assign |

### Example: Create a Guest Network

```
cli uconfig edit> create interface guest role downstream
cli uconfig edit> interface guest
cli uconfig edit interface "guest"> set isolate-hosts 1 vlan-id 100
cli uconfig edit interface "guest"> add service ssh
cli uconfig edit interface "guest"> ipv4
cli uconfig edit interface "guest" ipv4>
```

### IPv4 Settings

```
cli uconfig edit interface "lan"> ipv4
cli uconfig edit interface "lan" ipv4>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| addressing | enum | none | none, static, dynamic |
| subnet | CIDR4 | | Static IPv4 in CIDR notation (e.g. 192.168.1.1/24, or auto/24) |
| gateway | IPv4 | | Static gateway address |
| dns-servers | IPv4 (list) | | DNS servers |
| send-hostname | bool | true | Include hostname in DHCP requests |
| disallow-upstream-subnet | CIDR4 (list) | | Block traffic to specified subnets |

#### DHCP Pool

```
cli uconfig edit interface "lan" ipv4> dhcp-pool
cli uconfig edit interface "lan" ipv4 dhcp-pool>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| lease-first | int (min 1) | 10 | Last octet of the first pool address |
| lease-count | int (min 10) | 200 | Number of addresses in the pool |
| lease-time | string | 6h | Lease duration (e.g. 6h, 1d, 30m) |
| use-dns | IPv4 (list) | | DNS servers to announce via DHCP option 6 |

#### Static DHCP Leases

From the IPv4 context, manage static DHCP leases:

```
cli uconfig edit interface "lan" ipv4> create dhcp-lease my-host
cli uconfig edit interface "lan" ipv4> dhcp-lease my-host
cli uconfig edit interface "lan" ipv4 dhcp-lease "my-host">
cli uconfig edit interface "lan" ipv4> list dhcp-lease
cli uconfig edit interface "lan" ipv4> destroy dhcp-lease my-host
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| macaddr | MAC | *required* | Host MAC address |
| lease-offset | int | *required* | IP offset from the first pool address |
| lease-time | string | *required* | Lease duration |
| publish-hostname | bool | true | Make hostname available via local DNS |

### IPv6 Settings

```
cli uconfig edit interface "lan"> ipv6
cli uconfig edit interface "lan" ipv6>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| addressing | enum | dynamic | dynamic or static |
| subnet | CIDR6 | | Static IPv6 in CIDR notation (use auto/64 for automatic) |
| gateway | IPv6 | | Static IPv6 gateway |
| prefix-size | int (0-64) | | Prefix size to request or allocate |

#### DHCPv6

```
cli uconfig edit interface "lan" ipv6> dhcpv6
cli uconfig edit interface "lan" ipv6 dhcpv6>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| mode | enum | hybrid | hybrid, stateless, stateful, relay |
| announce-dns | IPv6 (list) | | DNS servers to announce via DHCPv6 |
| filter-prefix | CIDR6 | ::/0 | Filter advertised prefixes |

### Example: Downstream Interface with Static IPv4

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> set role downstream
cli uconfig edit interface "lan"> ipv4
cli uconfig edit interface "lan" ipv4> set addressing static subnet 192.168.1.1/24
cli uconfig edit interface "lan" ipv4> dhcp-pool
cli uconfig edit interface "lan" ipv4 dhcp-pool> set lease-first 10 lease-count 200 lease-time 12h
cli uconfig edit interface "lan" ipv4 dhcp-pool> commit
```

### SSIDs (Wireless Networks)

From within an interface, manage wireless SSIDs:

```
cli uconfig edit interface "lan"> create ssid <name>
cli uconfig edit interface "lan"> list ssid
cli uconfig edit interface "lan"> ssid <name>
cli uconfig edit interface "lan"> destroy ssid <name>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| ssid | string (1-32) | OpenWrt | Broadcast SSID name |
| mode | enum | encrypted | Template mode: open, encrypted, enterprise, opportunistic, batman-adv |
| security | enum | maximum | legacy, compatibility, or maximum (for encrypted/enterprise/opportunistic) |
| key | string (8-63) | *required for encrypted/batman-adv* | Pre-shared key |
| radius-server | enum | local | RADIUS server name (for enterprise mode) |
| bss-mode | enum | ap | ap, sta, mesh, wds-ap, wds-sta, wds-repeater |
| radio | enum (list) | all bands | Radio bands to broadcast on (e.g. 2G, 5G, 6G) |
| hidden | bool | false | Hide SSID in beacons (AP mode only) |
| roaming | bool | true | Enable 802.11r fast roaming (AP mode only) |
| disable | bool | false | Do not bring up this SSID on apply |
| isolate-clients | bool | false | Isolate wireless clients from each other (AP mode only) |
| rate-limit | int | | Per-client rate limit in Mbps (AP mode only) |

#### Security Modes Explained

| Mode | Security | Result |
|------|----------|--------|
| open | - | No encryption |
| encrypted | maximum | WPA3-SAE (requires WPA3-capable clients) |
| encrypted | compatibility | SAE-mixed (supports both WPA2 and WPA3 clients) |
| encrypted | legacy | WPA2-PSK only (required for multi-psk) |
| enterprise | maximum | WPA3-Enterprise with RADIUS authentication |
| enterprise | compatibility | WPA3-mixed Enterprise (supports WPA2/WPA3 clients) |
| opportunistic | maximum | OWE (encrypted without a password) |
| opportunistic | compatibility | OWE-transition (fallback for clients that only support open) |
| batman-adv | - | Mesh networking with PSK encryption |

#### Multi-PSK (Per-User Pre-Shared Keys)

Multi-PSK requires encrypted mode with legacy security (WPA2-PSK). The create, list, destroy, and multi-psk commands are only available when the SSID is configured with mode encrypted and security legacy.

From within an SSID, manage per-user PSK entries:

```
cli uconfig edit interface "lan" ssid "office"> create multi-psk <name>
cli uconfig edit interface "lan" ssid "office"> list multi-psk
cli uconfig edit interface "lan" ssid "office"> multi-psk <name>
cli uconfig edit interface "lan" ssid "office"> destroy multi-psk <name>
```

| Parameter | Type | Description |
|-----------|------|-------------|
| key | string (8-63) | *required* -- PSK for this user |
| macaddr | MAC (list) | MAC addresses bound to this PSK |
| vlan-id | int (1-4095) | VLAN to assign to this user |

### Example: Create an Encrypted SSID

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> create ssid office mode encrypted security maximum key "MySecurePass123" ssid "Office" radio 5G
cli uconfig edit interface "lan"> ssid office
cli uconfig edit interface "lan" ssid "office"> show
cli uconfig edit interface "lan" ssid "office"> commit
```

### Example: Enterprise SSID with RADIUS

```
cli uconfig edit interface "lan"> create ssid enterprise mode enterprise radius-server enterprise-radius ssid "Enterprise"
cli uconfig edit interface "lan"> ssid enterprise
cli uconfig edit interface "lan" ssid "enterprise"> show
cli uconfig edit interface "lan" ssid "enterprise"> commit
```

---

## Services

```
cli uconfig edit> services
cli uconfig edit services>
```

### Listing Available Services

```
cli uconfig edit services> list
```

### SSH

```
cli uconfig edit services> ssh
cli uconfig edit services ssh>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| port | int (1-65535) | 22 | SSH server port |
| cli-port | int (1-65535) | 2222 | CLI-over-SSH port |
| password-authentication | bool | true | Allow password-based logins |
| authorized-keys | string (list) | | Public SSH keys for key-based access |

### CLI (CLI-over-SSH)

```
cli uconfig edit services> cli
cli uconfig edit services cli>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| port | int (1-65535) | 2222 | CLI-over-SSH port |

This provides a dedicated SSH port that drops directly into the CLI rather than a shell.

### Remote Syslog (log)

```
cli uconfig edit services> log
cli uconfig edit services log>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| host | host | | Remote syslog server address |
| port | int (100-65535) | | Remote syslog port |
| proto | enum | udp | Protocol: tcp, udp |
| size | int (min 32) | 1000 | Log buffer size in KiB |
| priority | int (0-7) | 7 | Syslog priority filter (0=emergency only, 7=all) |

### Built-in RADIUS Server (radius-server)

```
cli uconfig edit services> radius-server
cli uconfig edit services radius-server>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| auth-port | int (1024-65535) | 1812 | RADIUS authentication port |
| acct-port | int (1024-65535) | 1813 | RADIUS accounting port |
| secret | string | secret | Shared secret for RADIUS clients |

#### RADIUS Users

From within the radius-server context, manage local RADIUS users:

```
cli uconfig edit services radius-server> create user <name>
cli uconfig edit services radius-server> list user
cli uconfig edit services radius-server> user <name>
cli uconfig edit services radius-server> destroy user <name>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| auth-type | enum | password | password, certificate, both |
| password | string | | User password (required for password/both auth types) |
| vlan-id | int (1-4094) | | Assign user to a VLAN |
| rate-limit-upload | int | | Upload rate limit in kbps |
| rate-limit-download | int | | Download rate limit in kbps |

### IEEE 802.1X (Wired Authentication)

```
cli uconfig edit services> ieee8021x
cli uconfig edit services ieee8021x>
```

| Parameter | Type | Description |
|-----------|------|-------------|
| radius-server | enum | RADIUS server name from definitions |

### Example: Configure SSH Access

```
cli uconfig edit> services
cli uconfig edit services> ssh
cli uconfig edit services ssh> set port 22 password-authentication 0
cli uconfig edit services ssh> add authorized-keys "ssh-ed25519 AAAA... admin@laptop"
cli uconfig edit services ssh> show
cli uconfig edit services ssh> commit
```

### Example: Set Up Built-in RADIUS with Users

```
cli uconfig edit services> radius-server
cli uconfig edit services radius-server> set secret MyRadiusSecret
cli uconfig edit services radius-server> create user alice auth-type password password alicepass vlan-id 10
cli uconfig edit services radius-server> user alice
cli uconfig edit services radius-server user "alice"> show
cli uconfig edit services radius-server user "alice"> commit
```

---

## Includes (Configuration Sources)

```
cli uconfig edit> includes
cli uconfig edit includes>
```

Manage external configuration sources that are merged into the active configuration.

| Command | Description |
|---------|-------------|
| show | Display current include sources |
| set \<name\> source \<spec\> | Add or update an include source |
| unset \<name\> | Remove an include source |

Source format: ucoord:\<name\> for remote coordination, local:\<name\> for local sources.

### Example

```
cli uconfig edit includes> set enterprise source ucoord:enterprise-policy
cli uconfig edit includes> show
cli uconfig edit includes> commit
```

---

## Examples (Pre-Built Configurations)

```
cli uconfig> examples
cli uconfig examples>
```

| Command | Description |
|---------|-------------|
| list | Show available example configurations |
| apply \<name\> | Apply an example configuration |

Example configurations are stored in /etc/uconfig/examples/ as JSON files.

```
cli uconfig examples> list
cli uconfig examples> apply basic-home
```

---

## Events

```
cli uconfig> event
cli uconfig event>
```

| Command | Description |
|---------|-------------|
| log | Display system event log |

---

## Common Workflows

### Initial Setup

```
root@ap:~# cli
cli> uconfig
cli uconfig> edit

cli uconfig edit> unit
cli uconfig edit unit> set hostname MyAP timezone Europe/London
cli uconfig edit unit> commit

cli uconfig edit> radios "5G"
cli uconfig edit radios "5G"> set channel-mode HE channel-width 80 channel auto
cli uconfig edit radios "5G"> commit

cli uconfig edit> interface lan
cli uconfig edit interface "lan"> set role downstream
cli uconfig edit interface "lan"> ipv4
cli uconfig edit interface "lan" ipv4> set addressing static subnet 192.168.1.1/24
cli uconfig edit interface "lan" ipv4> dhcp-pool
cli uconfig edit interface "lan" ipv4 dhcp-pool> set lease-first 10 lease-count 200 lease-time 12h
cli uconfig edit interface "lan" ipv4 dhcp-pool> commit

cli uconfig edit> interface lan
cli uconfig edit interface "lan"> create ssid home mode encrypted key "MyWiFiPassword" ssid "Home"
cli uconfig edit interface "lan"> ssid home
cli uconfig edit interface "lan" ssid "home"> commit
```

### Adding a Guest Network

```
cli uconfig edit> create interface guest role downstream
cli uconfig edit> interface guest
cli uconfig edit interface "guest"> set isolate-hosts 1 vlan-id 100
cli uconfig edit interface "guest"> ipv4
cli uconfig edit interface "guest" ipv4> set addressing static subnet 192.168.100.1/24
cli uconfig edit interface "guest" ipv4> dhcp-pool
cli uconfig edit interface "guest" ipv4 dhcp-pool> set lease-first 10 lease-count 100 lease-time 2h
cli uconfig edit interface "guest" ipv4 dhcp-pool> commit

cli uconfig edit> interface guest
cli uconfig edit interface "guest"> create ssid guest mode open ssid "Guest"
cli uconfig edit interface "guest"> ssid guest
cli uconfig edit interface "guest" ssid "guest"> set isolate-clients 1 rate-limit 10
cli uconfig edit interface "guest" ssid "guest"> commit
```

### Enterprise WiFi with Local RADIUS

```
cli uconfig edit> services
cli uconfig edit services> radius-server
cli uconfig edit services radius-server> set secret RadiusSecret123
cli uconfig edit services radius-server> create user bob auth-type password password bobpass
cli uconfig edit services radius-server> user bob
cli uconfig edit services radius-server user "bob"> commit

cli uconfig edit> interface lan
cli uconfig edit interface "lan"> create ssid enterprise mode enterprise radius-server local ssid "Enterprise" security maximum
cli uconfig edit interface "lan"> ssid enterprise
cli uconfig edit interface "lan" ssid "enterprise"> commit
```

### Checking and Rolling Back

```
cli uconfig> status
cli uconfig> list
cli uconfig> dry-run
cli uconfig> rollback 1709312400
```

---

## Parameter Types Reference

| Type | Format | Example |
|------|--------|---------|
| bool | 0 or 1 | 1 |
| int | Numeric (may have min/max) | 1812 |
| string | Text (may have min/max length) | MyHostname |
| enum | One of a fixed set of values | upstream |
| host | IP address or hostname | 192.168.1.1 or ntp.example.com |
| ipv4 | IPv4 address | 10.0.0.1 |
| ipv6 | IPv6 address | 2001:db8::1 |
| cidr4 | IPv4 with prefix length | 192.168.1.0/24 |
| cidr6 | IPv6 with prefix length | fdca:1234::/48 |
| macaddr | MAC address | aa:bb:cc:dd:ee:ff |

List parameters (marked "list" in the tables) accept multiple values via add/remove operations, or multiple values passed to set.
