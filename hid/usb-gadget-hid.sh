#!/usr/bin/env bash
set -euo pipefail

G=/sys/kernel/config/usb_gadget/g_hid
HID_FN=hid.usb0

_report_desc_hex() {
# 표준 키보드 HID Report Descriptor (hex, 한 줄)
cat <<'DESC'
05010906A101050719E029E71500250175019508810295017508810395057501050819012905910295017503910395067508150025650507190029658100C0
DESC
}

start() {
  modprobe libcomposite

  # 이미 떠 있으면 중복 생성 방지
  if [ -d "$G" ]; then
    echo "[WARN] Gadget already exists. Doing nothing."
    return 0
  fi

  mkdir -p "$G"
  cd "$G"

  # (연구/실험용 예시 VID/PID)
  echo 0x1d6b > idVendor
  echo 0x0104 > idProduct
  echo 0x0200 > bcdUSB

  mkdir -p strings/0x409
  echo "0001"             > strings/0x409/serialnumber
  echo "Raspberry Pi"     > strings/0x409/manufacturer
  echo "Pi HID Keyboard"  > strings/0x409/product

  mkdir -p configs/c.1
  mkdir -p configs/c.1/strings/0x409
  echo "Config 1: HID"    > configs/c.1/strings/0x409/configuration
  echo 120                > configs/c.1/MaxPower

  # HID 기능(키보드)
  mkdir -p functions/${HID_FN}
  echo 1 > functions/${HID_FN}/protocol     # Keyboard
  echo 1 > functions/${HID_FN}/subclass
  echo 8 > functions/${HID_FN}/report_length

  # 리포트 디스크립터 기록 (hex → binary)
  _report_desc_hex | xxd -r -p > functions/${HID_FN}/report_desc

  # 구성에 기능 연결
  ln -s functions/${HID_FN} configs/c.1/

  # UDC 바인딩
  UDC=$(ls /sys/class/udc | head -n1)
  if [ -z "${UDC:-}" ]; then
    echo "[ERROR] No UDC found. Is dwc2 loaded and in peripheral mode?"
    exit 1
  fi
  echo "$UDC" > UDC

  echo "[OK] HID gadget up. Device should create /dev/hidg0 on the Pi."
  echo "     Send key reports by writing to /dev/hidg0."
}

stop() {
  if [ ! -d "$G" ]; then
    echo "[INFO] No gadget to stop."
    return 0
  fi

  # 가젯 디렉토리로 이동
  if ! cd "$G"; then
    echo "[ERROR] Cannot enter gadget directory $G. Aborting stop."
    return 1
  fi

  echo "Stopping USB Gadget $G..."

  # 1) UDC 언바인딩 (가장 먼저)
  # 파일에 내용을 써서 언바인딩. (빈 문자열)
  if [ -f "UDC" ]; then
    echo "" | sudo tee UDC > /dev/null 2>&1 || true
    echo "  - UDC Unbound."
  fi

  # 2) configs/의 기능 링크 제거
  # find 명령은 성공적으로 작동하지만, 에러 메시지를 숨기지 않습니다.
  # (에러가 나도 다음 단계로 진행)
  if [ -L "configs/c.1/hid.usb0" ]; then
    rm -f configs/c.1/hid.usb0
    echo "  - Function link removed from config."
  fi

  # 3) functions/hid.usb0 디렉토리의 내부 파일들을 먼저 제거해야 합니다.
  # configfs 특성상 내부 파일을 먼저 rm으로 제거한 후, 빈 디렉토리를 rmdir로 제거해야 합니다.

  # functions/hid.usb0 내부 파일 제거 (rm으로 제거 가능)
  if [ -d "functions/${HID_FN}" ]; then
    # HID function의 핵심 파일들 (protocol, subclass, report_length, report_desc)
    # dev 파일은 커널이 관리하므로 제거 불가능 (attempted by rm -rf previously)

    # 3-1. report_desc 파일 명시적 제거 (이것이 rm -rf 대신 rmdir을 위해 필요)
    rm -f "functions/${HID_FN}/report_desc" 2>/dev/null || true

    # 3-2. function 디렉토리 제거 (이제 비었어야 함)
    rmdir "functions/${HID_FN}" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "  - Function directory (functions/hid.usb0) removed."
    else
        echo "[WARN] Could not remove functions/hid.usb0. Check if it's truly empty."
    fi
  fi


  # 4) strings/ 및 configs/ 디렉터리 정리 (역순으로 비어 있을 때만 rmdir)
  rmdir configs/c.1/strings/0x409 2>/dev/null || true
  rmdir configs/c.1               2>/dev/null || true
  rmdir strings/0x409             2>/dev/null || true
  echo "  - Config/Strings directories cleaned."


  # 5) 가젯 루트 제거 (마지막)
  cd /sys/kernel/config/usb_gadget || true
  rmdir g_hid 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "[OK] HID gadget down. Directory g_hid removed."
  else
    echo "[WARN] Could not remove g_hid. Configuration might still be partially loaded."
  fi
}

case "${1:-}" in
  start) start ;;
  stop)  stop  ;;
  restart) stop; start ;;
  *) echo "Usage: $0 {start|stop|restart}"; exit 1 ;;
esac