# ucoord WebSocket Interface

JSON-RPC 2.0 protocol reference for the ucoord web UI.

Sources:
- modules/ucoord/usr/share/ucode/ucoord/uwsd-handler.uc
- modules/ucoord/usr/share/ucode/ucoord/uwsd/jsonrpc.uc
- modules/ucoord/usr/share/ucode/ucoord/uwsd/auth.uc


## Connection

- **Endpoint:** ws://$host:80/ucoord
- **Subprotocol:** ui (must be included in the WebSocket handshake;
  connections without this subprotocol are rejected with code 1003)
- **Maximum message size:** 32 KB
- **Idle timeout:** 120 seconds (configured in
  modules/ucoord/etc/uwsd-ucoord-ui.conf)

On connect, the server sends a login-required event after 200ms to
prompt authentication.


## Authentication

Credentials are stored in /etc/uconfig/ucoord/credentials as JSON:

```json
{
  "admin": {
    "hash": "<sha512-hex>"
  }
}
```

The login method compares the SHA-512 hash of the supplied password
against the stored hash. Authentication state is per-connection;
there are no tokens or sessions.

Password constraints (enforced by change-password):
- Minimum length: 8 characters
- Maximum length: 64 characters


## Request Format

Standard JSON-RPC 2.0 request:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "<method-name>",
  "params": { }
}
```


## Response Format

**Success:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": { }
}
```

**Error:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32603,
    "message": "description",
    "data": { }
  }
}
```


## Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| -32700 | ERROR_PARSE | JSON parse failure |
| -32600 | ERROR_INVALID_REQUEST | Missing jsonrpc: "2.0" or method field |
| -32601 | ERROR_METHOD_NOT_FOUND | Unknown method name |
| -32602 | ERROR_INVALID_PARAMS | Missing or invalid parameters |
| -32603 | ERROR_INTERNAL | Internal error or ubus call failure |
| -32001 | ERROR_LOGIN_REQUIRED | Method requires authentication |
| -32000 | ERROR_INVALID_PASSWORD | Login failed |


## Server-Initiated Events

Events are JSON-RPC notifications (no id field):

```json
{
  "jsonrpc": "2.0",
  "method": "<event-name>"
}
```

| Event | When | Params |
|-------|------|--------|
| login-required | Immediately after connection | none |


## Methods

### login

Authenticate with the server. This is the only method that does not
require prior authentication.

**Params:** { "password": "..." }

**Result:** { "success": true }

**Errors:** ERROR_INVALID_PASSWORD on wrong password,
ERROR_INVALID_PARAMS if password is missing.


### logout

End the authenticated session.

**Params:** none

**Result:** { "success": true }


### change-password

Change the admin password.

**Params:** { "password": "..." }

**Result:** { "success": true }

**Errors:** ERROR_INVALID_PARAMS if password is missing or does
not meet length constraints.


### ping

Connection keepalive.

**Params:** none

**Result:** { "success": true }


### list

List all venues and their peers.

**Params:** none

**Result:** Proxied from ucoord ubus status method. Returns
{ "venues": { "$venue": { "$peer": { ... } } } }.


### status

Identical to list - returns venue/peer status.

**Params:** none

**Result:** Same as list.


### info

Query system information from a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Output of ubus call system info on the peer (uptime,
load, memory).


### system-info

Alias for info - identical behaviour.


### state

Query runtime state (ports, radios) from a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Proxied from ucoord ubus state method.


### config-get

Retrieve the active configuration from a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** The peer's active uconfig JSON document.


### config-test

Validate a configuration on a remote peer without applying it.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| config | object | yes | Full uconfig JSON document |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Validation result from uconfig-apply -t.


### config-apply

Push and apply a configuration on a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| config | object | yes | Full uconfig JSON document |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Validation result. The peer applies the config
asynchronously after responding.


### reboot

Reboot a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Timeout in milliseconds |

**Result:** { "ok": true, "venue": "...", "peer": "..." }


### sysupgrade

Upgrade firmware on a remote peer.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| url | string | yes | Firmware image URL |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Proxied from ucoord ubus sysupgrade method.


### include

Manage include files on a venue.

**Params:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| action | string | yes | list, get, set, or delete |
| name | string | yes | Include file name |
| content | object | for set | Include file content |
| timeout | integer | no | Timeout in milliseconds |

**Result:** Depends on action - list returns a name-to-UUID map,
get returns the full include content, set and delete return
{ "ok": true }.


### reload

Reload the ucoord daemon configuration.

**Params:** none

**Result:** Proxied from ucoord ubus reload method.
