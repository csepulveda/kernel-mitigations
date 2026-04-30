#!/bin/sh
set -e

BLACKLIST_FILE="/host-modprobe-d/disable-algif-aead.conf"
NODE=$(cat /proc/sys/kernel/hostname 2>/dev/null || echo "unknown")

# 1. Verify Amazon Linux
if [ ! -f /proc/version ]; then
    echo "[mitigation] ERROR: cannot read /proc/version — aborting" >&2
    exit 1
fi

OS_ID=$(grep -i "^ID=" /host-os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")
if [ "$OS_ID" != "amzn" ]; then
    echo "[mitigation] ERROR: not running on Amazon Linux (ID=${OS_ID}) — aborting" >&2
    exit 1
fi
echo "[mitigation] node=${NODE} OS=Amazon Linux — proceeding"

# 2. Unload module if loaded
if lsmod | grep -q "^algif_aead "; then
    echo "[mitigation] ALERT: algif_aead is loaded on node=${NODE} — attempting unload"
    if modprobe -r algif_aead; then
        echo "[mitigation] ALERT: algif_aead unloaded successfully on node=${NODE}"
    else
        echo "[mitigation] WARNING: algif_aead could not be unloaded on node=${NODE} (module in use) — blacklist applied for next boot"
    fi
else
    echo "[mitigation] algif_aead is not loaded on node=${NODE}"
fi

# 3. Add to blacklist
echo "install algif_aead /bin/false" > "$BLACKLIST_FILE"
echo "[mitigation] blacklist written: ${BLACKLIST_FILE} on node=${NODE}"

echo "[mitigation] done on node=${NODE}"
