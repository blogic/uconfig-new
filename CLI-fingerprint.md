# Fingerprint CLI Reference

Enables device fingerprinting on interfaces where the service is enabled. This module has no configurable parameters -- it is purely activated by adding it to an interface's service list.

## Example

```
cli uconfig edit> interface lan
cli uconfig edit interface "lan"> add service fingerprint
cli uconfig edit interface "lan"> commit
```
