# QoS CLI Reference

Configures traffic classification using qosify on interfaces where the service is enabled. Flows are classified into predefined service classes from qos.json, and bulk flow detection can be tuned via DSCP and PPS thresholds. It has two CLI entry points: a uconfig service for configuration, and a top-level command for traffic statistics.

---

## Configuration

Enable the service on an interface:

```
cli uconfig edit> interface wan
cli uconfig edit interface "wan"> add service quality-of-service
cli uconfig edit interface "wan"> commit
```

Configure QoS parameters:

```
cli uconfig edit> services
cli uconfig edit services> quality-of-service
cli uconfig edit services quality-of-service>
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| bulk-dscp | enum | CS0 | DSCP value assigned to bulk flows |
| bulk-pps | int | 0 | PPS rate triggering bulk flow classification |
| services | enum (list) | | Predefined service classifiers from qos.json |

Available service names: `all`, `amazon-prime`, `browsing`, `disney-plus`, `facetime`, `google-meet`, `hbo`, `jitsi`, `networking`, `netflix`, `rtmp`, `stun`, `teams`, `voip`, `vowifi`, `webex`, `youtube`, `zoom`.

### Example

```
cli uconfig edit interface "wan"> add service quality-of-service
cli uconfig edit interface "wan"> commit

cli uconfig edit> services
cli uconfig edit services> quality-of-service
cli uconfig edit services quality-of-service> add services youtube zoom voip
cli uconfig edit services quality-of-service> set bulk-dscp CS0 bulk-pps 500
cli uconfig edit services quality-of-service> show
cli uconfig edit services quality-of-service> commit
```

---

## Traffic Statistics

```
cli> qosify
```

Shows per-class and per-DSCP packet and byte counters from the qosify eBPF classifier. Classes and DSCP values with zero traffic are omitted.

### Example

```
cli> qosify
QoS Statistics:

Classes:
    besteffort:        296 packets, 52869 bytes
    network_services:  48 packets, 20542 bytes
    voice:             16 packets, 1440 bytes

DSCP:
    CS0:               296 packets, 52869 bytes
    CS3:               48 packets, 20542 bytes
    CS6:               16 packets, 1440 bytes
```
