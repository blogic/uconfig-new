# mDNS CLI Reference

Configures mDNS (multicast DNS) announcements on interfaces where the service is enabled. Allows the device to be discovered by name on the local network.

Enable the service on an interface:

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> add service mdns
cli uconfig edit interface "lan"> commit
```

Configure mDNS parameters:

```
cli uconfig edit> services
cli uconfig edit services> mdns
cli uconfig edit services mdns>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| additional-hostnames | string (list) | | Additional hostnames to announce via mDNS |

## Example

```
cli uconfig edit interface "lan"> add service mdns
cli uconfig edit interface "lan"> commit

cli uconfig edit> services
cli uconfig edit services> mdns
cli uconfig edit services mdns> add additional-hostnames home-ap router
cli uconfig edit services mdns> show
cli uconfig edit services mdns> commit
```
