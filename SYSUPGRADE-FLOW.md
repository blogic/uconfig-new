# System Upgrade Flow

## Overview

Firmware upgrade is a 4-step process:
1. Request upload token via WebSocket
2. Upload firmware file via HTTP PUT
3. Receive validation event via WebSocket
4. Apply upgrade via WebSocket (if validation succeeded)

## Step 1: Request Upload Token

**Request:**
```json
{"jsonrpc": "2.0", "method": "sysupgrade", "params": {"action": "token"}, "id": 1}
```

**Response:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "token": "550e8400-e29b-41d4-a716-446655440000",
    "upload_url": "/upload/550e8400-e29b-41d4-a716-446655440000",
    "max_size": 52428800,
    "expires_in": 600
  },
  "id": 1
}
```

## Step 2: Upload Firmware File

**HTTP Request:**
```
PUT /upload/550e8400-e29b-41d4-a716-446655440000 HTTP/1.1
Host: 192.168.1.1
Content-Length: 12345678
X-Filename: firmware.bin

<binary firmware data>
```

**Success Response (HTTP 201):**
```json
{
  "token": "550e8400-e29b-41d4-a716-446655440000",
  "file_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "file_path": "/tmp/sysupgrade.1234567890",
  "filesize": 12345678,
  "upload_duration": 5,
  "token_type": "sysupgrade",
  "status": "upload_complete"
}
```

**Failure Response (HTTP 400):**
```json
{
  "status": "validation_failed",
  "error": "Firmware validation failed (exit code: 1)"
}
```

## Step 3: Receive Validation Event

The server automatically validates uploaded firmware using `sysupgrade --test` and broadcasts the result to all connected clients.

**Success Event:**
```json
{
  "jsonrpc": "2.0",
  "method": "sysupgrade-validation-success",
  "params": {
    "file_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7"
  }
}
```

**Failure Event:**
```json
{
  "jsonrpc": "2.0",
  "method": "sysupgrade-validation-failed",
  "params": {
    "error": "Firmware validation failed (exit code: 1)"
  }
}
```

## Step 4: Apply Upgrade

Once validation succeeds, trigger the actual upgrade.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "method": "sysupgrade",
  "params": {
    "action": "apply",
    "file_id": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "keep_config": true
  },
  "id": 2
}
```

**Response:**
```json
{"jsonrpc": "2.0", "result": {"success": true}, "id": 2}
```

**Upgrade Event:**
```json
{"jsonrpc": "2.0", "method": "upgrading"}
```

After sending the "upgrading" event, the server closes all connections and performs the upgrade after a 2-second delay.

## Flow Diagram

```
Frontend                    Backend
   |                           |
   |--sysupgrade(token)------->|
   |<------token + upload_url--|
   |                           |
   |--HTTP PUT firmware------->|
   |                           |--validates firmware
   |<------HTTP 201------------|
   |                           |
   |<--validation-success event|
   |                           |
   | (user confirms)           |
   |                           |
   |--sysupgrade(apply)------->|
   |<------success-------------|
   |<--"upgrading" event-------|
   |                           |
   X (connection closed)       X--upgrades after 2s
```

## Important Notes

- **Token expires in 10 minutes** - must upload within this timeframe
- **Token is single-use** - cannot be reused
- **Max file size: 50MB** - enforced by server
- **keep_config parameter**:
  - `true` (default): Preserve configuration during upgrade
  - `false`: Factory reset - wipe configuration
- **Connection closes** after "upgrading" event - this is expected
- **Device reboots** after upgrade completes

## Error Handling

1. **Token expired**: Request a new token
2. **Upload fails**: Check file size (max 50MB) and token validity
3. **Validation fails**: Firmware image is invalid or corrupted
4. **Apply fails**: Check that file_id exists (from upload response)

## Example JavaScript

```javascript
// Step 1: Get upload token
ws.send(JSON.stringify({
  jsonrpc: "2.0",
  method: "sysupgrade",
  params: { action: "token" },
  id: 1
}));

// Handle token response
ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);

  if (msg.id === 1 && msg.result) {
    const { upload_url, token } = msg.result;
    uploadFirmware(upload_url, firmwareFile);
  }

  // Handle validation event
  if (msg.method === "sysupgrade-validation-success") {
    const fileId = msg.params.file_id;
    showApplyButton(fileId);
  }

  if (msg.method === "sysupgrade-validation-failed") {
    showError(msg.params.error);
  }
};

// Step 2: Upload firmware
async function uploadFirmware(url, file) {
  const response = await fetch(url, {
    method: 'PUT',
    headers: {
      'Content-Length': file.size,
      'X-Filename': file.name
    },
    body: file
  });

  const result = await response.json();
  console.log('Upload result:', result);
}

// Step 4: Apply upgrade
function applyUpgrade(fileId, keepConfig) {
  ws.send(JSON.stringify({
    jsonrpc: "2.0",
    method: "sysupgrade",
    params: {
      action: "apply",
      file_id: fileId,
      keep_config: keepConfig
    },
    id: 2
  }));
}
```
