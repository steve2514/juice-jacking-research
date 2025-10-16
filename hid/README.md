## HID 모드 사용(키보드 가젯) — Quick Start

### 준비물

- Raspberry Pi Zero / Zero 2W (OTG 지원 모델)  
- OTG 기능이 있는 **데이터 전용 케이블 또는 젠더**  
- 별도 **전원 공급(PWR IN)** 권장 (특히 장시간 실험 시 안정성 확보)  
- 아래 경로에 스크립트 및 서비스 파일이 준비되어 있어야 합니다:
    - /usr/local/sbin/switch-usb-role.sh
    - /usr/local/sbin/usb-gadget-hid.sh
    - /etc/systemd/system/usb-gadget.service

---

### HID 모드로 부팅
```bash
sudo switch-usb-role.sh hid --reboot
```

- Pi의 USB 컨트롤러를 기기(peripheral) 모드로 전환합니다.
- 재부팅 후 SSH로 다시 접속합니다 (Wi-Fi SSH 권장).
- /sys/class/udc/ 경로에 컨트롤러 이름이 보이면 성공입니다.

---

### HID 가젯 올리기 / 내리기
- HID 키보드 가젯 올리기
```bash
sudo systemctl start usb-gadget.service
```

- 상태 확인 (성공 시 /dev/hidg0 존재)
```bash
ls /dev/hidg0
```

- HID 가젯 내리기
```bash
sudo systemctl stop usb-gadget.service
```

- 부팅 시 자동으로 HID 가젯을 활성화하고 싶다면:
```bash
sudo systemctl enable usb-gadget.service
```

### HID 입력 테스트
- /dev/hidg0에 8바이트 HID 리포트를 직접 쓰면 호스트에 키 입력이 전달됩니다.

- 'a' 키 누르기
```bash
printf "\x00\x00\x04\x00\x00\x00\x00\x00" | sudo tee /dev/hidg0 > /dev/null
```

- 'a' 키 떼기
```bash
printf "\x00\x00\x00\x00\x00\x00\x00\x00" | sudo tee /dev/hidg0 > /dev/null
```

## HID 스크립트 작성 (파이썬)

> HID 키보드 가젯을 제어하기 위한 **연구·교육용 Python 스크립트 작성법**

---

### 핵심 개념

- HID 키보드는 항상 **8바이트 리포트(report)** 를 전송합니다:  
  `[modifier, reserved, key1, key2, key3, key4, key5, key6]`
- 키 입력은 **“누르기(press)” → 잠시 대기 → “떼기(release)”** 로 구성됩니다.
- 여러 글자를 연속으로 보낼 때는 이 과정을 **문자 단위로 반복**해야 합니다.
- 같은 키를 연속으로 입력할 때 `release()`가 없으면 중복 입력이 안 됩니다.

---

### 공통 HID 라이브러리 (`/usr/local/lib/hidlib.py`)

아래는 **US 레이아웃 기준**으로 알파벳, 숫자, 공백, 엔터 등 기본 입력을 지원하는 예시입니다.  
이 파일을 `/usr/local/lib/hidlib.py`로 저장해두면 다른 페이로드 스크립트에서 쉽게 import 할 수 있습니다.

### 페이로드 예시 (/usr/local/share/hidpayloads/demo_ab_space_cdef_enter.py)
```bash
import sys; sys.path.append('/usr/local/lib')
from hidlib import *

def main():
    tap(0, KEY["A"])             # a
    release()
    tap(MOD["LSHIFT"], KEY["A"]) # A
    tap(0, KEY["B"])             # b
    tap(MOD["LSHIFT"], KEY["B"]) # B
    tap(0, KEY["SPACE"])         # (space)
    tap(0, KEY["C"]); tap(0, KEY["D"])
    tap(0, KEY["ENTER"])         # (enter)
    tap(0, KEY["E"]); tap(0, KEY["F"])
    release()

if __name__ == "__main__":
    main()
```

- 핵심 요약:
    - tap() = 누르고 → 떼기 (press + release)
    - type_text("Hello World") → 자동 타이핑
    - wpm으로 속도 조절 (기본 240WPM)
    - 항상 release()로 키가 붙는 현상을 방지해야 함
    - US 키보드 기준 매핑 (IME/한글 전환은 별도 고려 필요)