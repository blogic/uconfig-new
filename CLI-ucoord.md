# ucoord CLI Reference

The ucoord module is a separate top-level CLI module for multi-device coordination. It manages a mesh of OpenWrt access points from a single CLI session. From the coordinator, you can create venues, invite hosts, remotely edit configurations, reboot peers, and push firmware upgrades.

```
cli> ucoord
cli ucoord>
```

---

## Top-Level Commands

| Command | Description |
|---------|-------------|
| join | Join a coordination network |
| status | Show coordinator status for all venues |
| list | List all connected peers across all venues |

### join

| Parameter | Type | Description |
|-----------|------|-------------|
| access-key | string | *required* -- Access key from invitation |
| local-network | string | *required* -- Local network interface to use |

---

## Venues

Venues group a set of coordinated devices. Each venue maps to a unet network.

```
cli ucoord> create venue <name> [password <password>]
cli ucoord> list venue
cli ucoord> venue <name>
cli ucoord> destroy venue <name>
```

Venue names are limited to 8 characters. Creating and destroying venues requires a configuration password (minimum 12 characters). If not provided on the command line, the CLI prompts interactively.

### Within a Venue

```
cli ucoord> venue my-site
cli ucoord venue "my-site">
```

| Command | Description |
|---------|-------------|
| status | Show venue network status |
| invite | Invite a new host to join the venue |
| list host | List hosts in this venue |
| host \<name\> | Select a host for management |
| destroy host \<name\> | Remove a host from the venue |

### invite

| Parameter | Type | Description |
|-----------|------|-------------|
| hostname | string | *required* -- Hostname for the new device |
| access-key | string | *required* -- Access key (pincode) for the host |
| password | string | Network configuration password (prompted if omitted) |
| timeout | int | Invitation timeout in seconds (default: 120) |

### include

Manage configuration include files distributed to venue members.

```
cli ucoord venue "my-site"> include
cli ucoord venue "my-site" include>
```

| Command | Description |
|---------|-------------|
| list | List all include files |
| show \<name\> | Display include file content |
| set \<name\> file \<path\> | Upload a local JSON file as an include |
| delete \<name\> | Delete an include file |

---

## Host Management

Select a host by name within a venue:

```
cli ucoord venue "my-site"> host my-ap
cli ucoord venue "my-site" host "my-ap">
```

| Command | Description |
|---------|-------------|
| info | Show host information (address, connection status, traffic) |
| state | Show host state (ports and radios) |
| edit | Open the full uconfig editor for the remote host's configuration |
| reboot | Reboot the remote host (requires confirmation) |
| sysupgrade \<url\> | Push a firmware image URL to the host (requires confirmation) |
| config | Enter the configuration management subcontext |

### config

```
cli ucoord venue "my-site" host "my-ap"> config
cli ucoord venue "my-site" host "my-ap" config>
```

| Command | Description |
|---------|-------------|
| status | Show the remote host's current raw configuration |
| validate \<file\> | Validate a local JSON config file against the remote host |
| push \<file\> | Push and apply a local JSON config file to the remote host |

### Remote Editing

The edit command fetches the remote host's configuration and opens the full uconfig editor locally. Changes are applied to the remote device on commit.

```
cli ucoord venue "my-site" host "my-ap"> edit
cli ucoord venue "my-site" host "my-ap" edit>
```

From here, all standard uconfig edit commands work (unit, interfaces, radios, services, etc.) but operate on the remote host's configuration.

---

## Examples

### Create a Venue and Invite a Host

```
cli> ucoord
cli ucoord> create venue office
cli ucoord> venue office
cli ucoord venue "office"> invite hostname lobby-ap access-key 123456
cli ucoord venue "office"> list host
```

### Remotely Configure a Host

```
cli> ucoord
cli ucoord> venue office
cli ucoord venue "office"> host lobby-ap
cli ucoord venue "office" host "lobby-ap"> info
cli ucoord venue "office" host "lobby-ap"> edit
cli ucoord venue "office" host "lobby-ap" edit> unit
cli ucoord venue "office" host "lobby-ap" edit unit> set hostname LobbyAP
cli ucoord venue "office" host "lobby-ap" edit unit> commit
```

### Check Status and Reboot

```
cli ucoord> status
cli ucoord> list
cli ucoord> venue office
cli ucoord venue "office"> host lobby-ap
cli ucoord venue "office" host "lobby-ap"> state
cli ucoord venue "office" host "lobby-ap"> reboot
```
