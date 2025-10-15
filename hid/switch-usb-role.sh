#!/usr/bin/env bash
# Raspberry Pi Zero 2W USB 역할 전환 스크립트 (Bookworm 전용)
# - HID(디바이스/peripheral) ↔ MTP(호스트/host) 전환
# - /boot/firmware/config.txt 파일만 수정
# - 기존 dtoverlay=dwc2 라인을 전부 제거하고, [all] 섹션에 단 한 줄만 추가
# - usb-gadget.service 있으면 HID 모드에서 enable, host 모드에서 disable
#
# 사용법:
#   sudo switch-usb-role.sh hid  [--reboot]
#   sudo switch-usb-role.sh host [--reboot]

set -euo pipefail

ROLE="${1:-}"
ACTION_REBOOT="${2:-}"

if [[ "$ROLE" != "hid" && "$ROLE" != "host" ]]; then
  echo "사용법: sudo $(basename "$0") {hid|host} [--reboot]"
  exit 1
fi

CFG="/boot/firmware/config.txt"
if [[ ! -f "$CFG" ]]; then
  echo "[ERROR] /boot/firmware/config.txt 파일을 찾을 수 없습니다."
  exit 1
fi

SERVICE_NAME="usb-gadget.service"

# 1) 서비스 정지 (있을 때만)
if systemctl list-unit-files | grep -q "^${SERVICE_NAME}"; then
  systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
fi

# 2) 백업 (하나만 유지)
cp -a "$CFG" "${CFG}.bak"
echo "[INFO] 백업 생성: ${CFG}.bak"

# 3) 기존 dwc2 관련 라인 모두 제거
sed -i -E '/^[[:space:]]*dtoverlay[[:space:]]*=[[:space:]]*dwc2([[:space:]]*,[[:space:]]*.*)?[[:space:]]*$/d' "$CFG"

# 4) 새 라인 준비
if [[ "$ROLE" == "hid" ]]; then
  NEWLINE='dtoverlay=dwc2,dr_mode=peripheral'
  WANT_SERVICE="enable"
else
  NEWLINE='dtoverlay=dwc2,dr_mode=host'
  WANT_SERVICE="disable"
fi

# 5) [all] 섹션 아래에 새 라인 삽입
if grep -q '^\[all\]' "$CFG"; then
  TMP="$(mktemp)"
  awk -v repl="$NEWLINE" '
    BEGIN{ins=0}
    /^\[all\]$/ && ins==0 {print; print repl; ins=1; next}
    {print}
    END{ if(ins==0) print repl }
  ' "$CFG" > "$TMP"
  mv "$TMP" "$CFG"
else
  printf '\n[all]\n%s\n' "$NEWLINE" >> "$CFG"
fi

# 6) 혹시 같은 줄이 여러 번 들어갔다면 마지막 것만 남기고 정리
tac "$CFG" | awk -v line="$NEWLINE" '
  $0==line { if(seen) next; seen=1 }
  {print}
' | tac > "${CFG}.tmp.$$"
mv "${CFG}.tmp.$$" "$CFG"

# 7) 서비스 토글
if systemctl list-unit-files | grep -q "^${SERVICE_NAME}"; then
  if [[ "$WANT_SERVICE" == "enable" ]]; then
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 || true
  else
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
  fi
fi

# 8) 결과 출력
echo "[OK] USB 역할 전환 완료 → $ROLE"
echo "     적용 파일 : $CFG"
echo "     추가된 라인: $NEWLINE"
echo "     백업 파일 : ${CFG}.bak"   # ← TS 참조 제거 (수정 포인트)
echo
echo "현재 적용된 dtoverlay 라인:"
grep -n 'dtoverlay=dwc2' "$CFG" || true
echo
if [[ "$ACTION_REBOOT" == "--reboot" ]]; then
  echo "[INFO] 지금 즉시 재부팅합니다..."
  reboot
else
  echo ">>> 적용하려면 재부팅 필요. 실행: sudo reboot"
fi