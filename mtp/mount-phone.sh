#!/usr/bin/env bash
set -euo pipefail
MNT=/mnt/phone

mkdir -p "$MNT"

echo "Attempting to acquire MTP interface..."
pkill gvfsd-mtp || true # 프로세스가 없어도 오류 발생하지 않도록 수정

# 마운트 시도
jmtpfs "$MNT"

# 마운트 성공 확인
if mountpoint -q "$MNT"; then
  echo "[OK] Mounted successfully at $MNT"
  echo "Browse: ls $MNT/'내장 저장공간'"
else
  # 이 메시지가 나오면 jmtpfs가 오류 없이 종료되었지만 마운트는 실패한 경우
  echo "[ERROR] jmtpfs command finished, but mountpoint $MNT not detected."
  exit 1
fi
