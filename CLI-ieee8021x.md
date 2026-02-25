# IEEE 802.1X CLI Reference

Configures wired IEEE 802.1X port-based network access control. Ports listed under `ieee8021x-ports` on an interface require RADIUS authentication before granting network access.

Enable the service on an interface:

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> add service ieee8021x
cli uconfig edit interface "lan"> commit
```

Configure 802.1X parameters:

```
cli uconfig edit> services
cli uconfig edit services> ieee8021x
cli uconfig edit services ieee8021x>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| radius-server | string | local | RADIUS server name ("local" for built-in server, or a name defined in the definitions block) |

Assign ports for 802.1X authentication on an interface (uses the same port syntax as regular `ports`):

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> set ieee8021x-ports lan1 auto lan2 auto
cli uconfig edit interface "lan"> commit
```

## Example

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> add service ieee8021x
cli uconfig edit interface "lan"> set ieee8021x-ports lan1 auto lan2 auto
cli uconfig edit interface "lan"> commit

cli uconfig edit> services
cli uconfig edit services> ieee8021x
cli uconfig edit services ieee8021x> set radius-server local
cli uconfig edit services ieee8021x> show
cli uconfig edit services ieee8021x> commit
```
