#!/usr/bin/env bash
set -euo pipefail
MNT=/mnt/phone

if mountpoint -q "$MNT"; then
  fusermount -u "$MNT"
  echo "[OK] Unmounted $MNT"
else
  echo "[INFO] Not mounted."
fi
