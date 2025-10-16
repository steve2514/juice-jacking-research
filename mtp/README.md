### 개요

이 레포는 Pi Zero 2W에서 USB 역할을 전환(HID ↔ MTP) 하고, MTP 마운트/백업을 자동화하는 스크립트를 제공합니다.

```bash
[Phone] ⇄(USB OTG)⇄ [Raspberry Pi Zero 2W]
     ▲ HID(Device) 모드: Pi가 키보드/마우스로 동작
     ▼ MTP(Host) 모드 : Pi가 폰 저장소를 마운트/백업
```
---

### 지원/테스트 환경
- Hardware: Raspberry Pi Zero 2W
- OS: Raspberry Pi OS (Bookworm)
- 케이블/젠더: OTG 지원 USB-C/마이크로USB 어댑터

**다른 보드/OS도 가능할 수 있으나 여기선 BooKworm + Zero 2W 기준으로 문서화했습니다.**

---

### 보안·윤리 고지

이 문서는 합법적이고 권한이 있는 장치에서의 백업·실험을 위한 것입니다.
타인의 기기/데이터에 대한 무단 접근·복사는 불법이며, 모든 책임은 사용자에게 있습니다.

---

### 필수 패키지 및 스크립트

```bash
sudo apt update
sudo apt install -y \
  mtp-tools jmtpfs simple-mtpfs \
  libmtp-runtime fuse3 \
  usbutils tmux jq \
  gvfs-backends
```

- 아래 경로에 스크립트 및 서비스 파일이 준비되어 있어야 합니다:
    - /usr/local/sbin/switch-usb-role.sh
    - /usr/local/sbin/mount-phone.sh
    - /usr/local/sbin/umount-phone.sh

---

### 모드 전환 (HID -> MTP)

```bash
sudo switch-usb-role.sh host --reboot
```

---

### MTP 사용

```bash
# 권장: tmux로 실행 (네트워크 끊겨도 작업 유지)
tmux

# 마운트
sudo mount-phone.sh

# 예) 사진 백업
cp -rv /mnt/phone/'내장 저장공간'/DCIM ~/phone_backup

# 해제
sudo umount-phone.sh
```

---

### 빠른 점검

```bash
# dwc2 설정 라인 확인 (Bookworm)
grep 'dtoverlay=dwc2' /boot/firmware/config.txt

# MTP 장치 탐지
mtp-detect | egrep 'Manufacturer|Model|friendlyname' -n || true
jmtpfs -l || true

# 마운트 상태 확인
mount | grep /mnt/phone || echo "Not mounted"
```