# Tailscale CLI Reference

Tailscale provides secure mesh networking via the Tailscale/WireGuard overlay network. It has two CLI entry points: a uconfig service for configuration, and a top-level module for operational commands.

---

## Configuration

Enable the service on an interface:

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> add service tailscale
cli uconfig edit interface "lan"> commit
```

Configure Tailscale parameters:

```
cli uconfig edit> services
cli uconfig edit services> tailscale
cli uconfig edit services tailscale>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| auto-start | bool | false | Automatically start Tailscale on boot |
| exit-node | bool | false | Advertise this device as an exit node |
| announce-routes | bool | false | Announce LAN routes to Tailnet |

### Example

```
cli uconfig edit interface "lan"> add service tailscale
cli uconfig edit interface "lan"> commit

cli uconfig edit> services
cli uconfig edit services> tailscale
cli uconfig edit services tailscale> set auto-start 1 announce-routes 1
cli uconfig edit services tailscale> show
cli uconfig edit services tailscale> commit
```

---

## Operational Commands

```
cli> tailscale
cli tailscale>
```

| Command | Description |
|---------|-------------|
| status | Show connection status, IPs, peers, and traffic statistics |
| login | Initiate authentication (prints an auth URL to visit) |
| start | Start the Tailscale tunnel |
| stop | Stop the Tailscale tunnel |

### Example: Authenticate and Connect

```
cli> tailscale
cli tailscale> login
cli tailscale> status
```

### Example: Stop and Restart the Tunnel

```
cli> tailscale
cli tailscale> stop
cli tailscale> start
cli tailscale> status
```
