# ucoord ubus API

ubus interface published by the ucoord daemon under the object name
ucoord.

ubus -v list ucoord


## Methods

### status

Return the current state of all venues and their peers.

**Response:**
```json
{
  "venues": {
    "<venue>": {
      "<peer>": {
        "state": "connected",
        "ts": 1700000000,
        "capabilities": { },
        "board": { },
        "includes": { "<name>": "<uuid>" }
      }
    }
  }
}
```


### reload

Reload venue configuration and ACLs.

**Response:**
```json
{
  "venues": ["venue-a", "venue-b"]
}
```


### reboot

Send a reboot command to a peer.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |


### sysupgrade

Trigger a firmware upgrade on a peer.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| url | string | yes | HTTP/S URL of the firmware image |
| action | string | no | test (validate only) or apply |
| timeout | integer | no | Request timeout in ms (default 3000) |

**Response:**

- test: { ok: true } if validation succeeds.
- apply: { ok: true, upgrade: true }.


### configure

Get, test, or apply a uconfig configuration on a peer.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| action | string | yes | get, test, or apply |
| config | object | for test/apply | Full uconfig JSON document |
| timeout | integer | no | Request timeout in ms (default 3000) |

**Response:**

- get: { ok: true, data: { ... } } with the active config.
- test: { ok: true, data: { ... } } with validation result.
- apply: same as test, plus "apply": true.


### info

Request system information from a peer.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Request timeout in ms (default 3000) |

**Response:** { ok: true, data: { ... } } with uptime, load, and
memory information.


### capabilities

Request device capabilities and wireless PHY information from a
peer.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | yes | Venue name |
| peer | string | yes | Peer host name |
| timeout | integer | no | Request timeout in ms (default 3000) |

**Response:**
```json
{
  "ok": true,
  "data": {
    "capabilities": { },
    "wiphy": { }
  }
}
```


### include

Manage include files. Include files are JSON documents identified
by name, each carrying a uuid for synchronisation across peers.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| venue | string | for set/delete | Venue name |
| action | string | yes | list, get, set, or delete |
| name | string | for get/set/delete | Include file name |
| content | object | for set | Include content (uuid is auto-assigned) |

**Response:**

- list: { ok: true, data: { name: uuid, ... } }
- get: { ok: true, data: { ... } }
- set: { ok: true }
- delete: { ok: true }
