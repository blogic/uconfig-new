# LLDP CLI Reference

Configures LLDP (Link Layer Discovery Protocol) announcements on interfaces where the service is enabled. Discovered by neighbouring switches and other network devices.

Enable the service on an interface:

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> add service lldp
cli uconfig edit interface "lan"> commit
```

Configure LLDP parameters:

```
cli uconfig edit> services
cli uconfig edit services> lldp
cli uconfig edit services lldp>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| hostname | string | OpenWrt | Hostname announced via LLDP |
| description | string | OpenWrt | Description announced via LLDP |
| location | string | LAN | Location announced via LLDP |

## Example

```
cli uconfig edit interface "lan"> add service lldp
cli uconfig edit interface "lan"> commit

cli uconfig edit> services
cli uconfig edit services> lldp
cli uconfig edit services lldp> set hostname HomeAP description "Living Room AP" location "Living Room"
cli uconfig edit services lldp> show
cli uconfig edit services lldp> commit
```
