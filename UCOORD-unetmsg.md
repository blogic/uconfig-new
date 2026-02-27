# ucoord unetmsg Protocol

Wire-level message format for ucoord peer communication over unetmsg
channels within unetd networks.

Source: modules/ucoord/usr/sbin/ucoord


## Transport

ucoord uses the unetmsg.client library to communicate. Each venue
(unetd network prefixed with ucoord_) has a dedicated pub/sub
channel.

Two sending primitives:

- chan.send(venue, type, data) - broadcast to all peers on a venue.
- chan.send_host(host, venue, type, data) - unicast to a specific
  peer on a venue.

Received messages arrive in the subscribe callback with three fields:

| Field | Type | Description |
|-------|------|-------------|
| args.type | string | Message type identifier |
| args.host | string | Sender's unetd host name |
| args.data | object | Message payload |


## Message Types

### announce (broadcast)

Sent on venue join, on peer list changes, and periodically after
receiving an announce from a new peer. Also sent when transitioning
between states (e.g. before rebooting or reconfiguring).

```json
{
  "type": "announce",
  "host": "<sender>",
  "data": {
    "state": "connected",
    "capabilities": { },
    "board": { },
    "includes": {
      "<name>": "<uuid>",
      ...
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| state | string | One of: pending, connected, rebooting, upgrading, reconfiguring |
| capabilities | object | Device capabilities (currently unused, reserved) |
| board | object | Output of ubus call system board |
| includes | object | Map of include name to UUID (integer timestamp) |

When includes are being actively edited (set or delete via the
include ubus method), two additional fields are present:

| Field | Type | Description |
|-------|------|-------------|
| include_edit | boolean | true to signal active include push |
| include_data | object | Map of include name to full include content |

Receivers that see include_edit: true apply the include data
directly via include_apply() rather than using the normal
include_sync() mechanism.


### reboot (broadcast)

Sent to all peers on a venue before the target peer reboots. The
receiving peer validates the sender against the venue ACL before
executing.

```json
{
  "type": "reboot",
  "host": "<sender>",
  "data": { }
}
```

On receipt, the daemon announces rebooting state on all venues
and schedules a reboot command after 5 seconds.


### RPC request (unicast)

All handler-based messages use a request/response pattern with
ID-based correlation. Requests are sent via chan.send_host() to a
specific peer.

```json
{
  "type": "<method>",
  "host": "<sender>",
  "data": {
    "id": 1,
    ...
  }
}
```

The id field is a monotonically increasing integer assigned by the
requesting peer. The sender starts a timeout timer (default 3000ms);
if no matching response arrives, the callback receives a timeout
error.

Receivers look up the handler for args.type, verify the sender
against the venue ACL, execute the handler, and send the result back
as a response message.


### response (unicast)

```json
{
  "type": "response",
  "host": "<responder>",
  "data": {
    "id": 1,
    "ok": true,
    "data": { },
    "error": "string"
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Correlates with the original request ID |
| ok | boolean | true on success, false on failure |
| data | object | Response payload (present on success) |
| error | string | Error description (present on failure) |

Additional flags may be present in certain responses:

- "apply": true in configure responses signals that the
  responder will apply the config after sending the response.
- "upgrade": true in sysupgrade responses signals that the
  responder will execute sysupgrade after sending the response.


## RPC Methods

### info

Request system information from a peer.

**Request:**
```json
{
  "type": "info",
  "data": { "id": 1 }
}
```

**Response data:** Output of ubus call system info (uptime, load,
memory).


### configure

Remote configuration get/test/apply.

**Request:**
```json
{
  "type": "configure",
  "data": {
    "id": 1,
    "action": "get|test|apply",
    "config": { }
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| action | yes | get, test, or apply |
| config | for test/apply | Full uconfig JSON document |

**get response data:** Contents of
/etc/uconfig/configs/uconfig.active.

**test response data:** Result from uconfig-apply -t (written
to /tmp/uconfig/apply.json).

**apply response:** Same as test, plus "apply": true in the
response envelope. After responding, the peer schedules a deferred
config apply (5-second delay), announces reconfiguring state, and
re-announces connected after another 5 seconds.


### capabilities

Request device capabilities and wireless PHY information.

**Request:**
```json
{
  "type": "capabilities",
  "data": { "id": 1 }
}
```

**Response data:**
```json
{
  "capabilities": { },
  "wiphy": { }
}
```

capabilities is constructed from the `uconfig.board_json` module.
wiphy is the live PHY data from the uconfig.wiphy module.


### sysupgrade

Remote firmware upgrade via image URL.

**Request:**
```json
{
  "type": "sysupgrade",
  "data": {
    "id": 1,
    "action": "test|apply",
    "url": "http://192.168.1.1/firmware.img"
  }
}
```

| Field | Required | Description |
|-------|----------|-------------|
| action | no | test (dry-run) or apply (default behaviour without action is apply) |
| url | yes | HTTP/S URL of the firmware image |

The handler downloads the image to /tmp/sysupgrade.img using
uclient-fetch, then validates it with sysupgrade -T.

**test response:** { ok: true } on success. The downloaded
image is removed after validation.

**apply response:** { ok: true, upgrade: true }. The image
is kept on disk. After responding, the peer announces upgrading
state on all venues and executes sysupgrade /tmp/sysupgrade.img
after a 5-second delay.

On any failure (download or validation), the image is removed and
an error response is returned (e.g. "error": "download failed" or
"error": "image validation failed").


### include_request

Request the contents of specific include files from a peer. Used
during include synchronisation when the local peer has outdated
or missing includes.

**Request:**
```json
{
  "type": "include_request",
  "data": {
    "id": 1,
    "names": ["include-a", "include-b"]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| names | array of strings | Include file names to retrieve |

**Response data:** Map of include name to full JSON content:
```json
{
  "include-a": { "uuid": 1700000000, ... },
  "include-b": { "uuid": 1700000001, ... }
}
```

Only includes that exist on the responding peer are returned;
missing names are silently omitted.


## ACL Enforcement

All RPC requests (handler-based messages) and reboot broadcasts
are subject to ACL checks. The daemon calls peer_authorized() to
verify the sender (args.host) against the venue's authorised peer
set.

When an unauthorised peer sends an RPC request, the daemon responds
with:
```json
{
  "type": "response",
  "data": { "id": 1, "ok": false, "error": "unauthorized" }
}
```

Unauthorised reboot broadcasts are silently dropped (logged but
not acted upon).

When no ucoord service is defined in the venue's unetd
configuration (empty ACL), all peers are authorised.
