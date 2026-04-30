#!/bin/sh
set -e

BLACKLIST_FILE="/host-modprobe-d/disable-algif-aead.conf"

echo "[cve-2026-31431] Writing modprobe blacklist..."
echo "install algif_aead /bin/false" > "$BLACKLIST_FILE"
echo "[cve-2026-31431] Blacklist written: $BLACKLIST_FILE"

if lsmod | grep -q "^algif_aead "; then
    if modprobe -r algif_aead; then
        echo "[cve-2026-31431] algif_aead unloaded successfully"
    else
        echo "[cve-2026-31431] WARNING: algif_aead is in use and could not be unloaded — blacklist is in place for next boot"
    fi
else
    echo "[cve-2026-31431] algif_aead was not loaded — blacklist is in place"
fi

echo "[cve-2026-31431] Mitigation complete on node $(cat /proc/sys/kernel/hostname)"
