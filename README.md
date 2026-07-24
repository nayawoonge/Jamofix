<div align="center">

![JamoFix](docs/images/banner.png)

# JamoFix

**맥 ↔ 윈도우 한글 파일명 문제(자소분리·인코딩 깨짐)를 자동으로 해결하는 macOS 앱**

[English](README.en.md) · 한국어

![platform](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![license](https://img.shields.io/badge/license-MIT-blue)

</div>

---

## 왜 필요한가요?

맥에서 만든 파일을 윈도우로 보내면 한글 이름이 깨지는 경험, 다들 있으실 겁니다.
원인은 두 가지입니다.

| 증상 | 원인 | JamoFix의 해결 |
|---|---|---|
| **자소분리** (`ㅎㅏㄴㄱㅡㄹ.txt`) | macOS는 파일명을 자모가 분리된 **NFD** 형태로 저장합니다. 맥에서는 조합돼 보이지만 윈도우·웹·리눅스에서는 `ㅎㅏㄴㄱㅡㄹ`로 풀어집니다. | NFD → **NFC** 정규화 (안전, 자동) |
| **파일명 깨짐** (`¿ù°£º¸°í¼­.hwp`) | 윈도우에서 만든 ZIP 등을 풀 때 CP949 바이트가 Latin-1 등으로 잘못 해석됩니다. | 인코딩 역추적 **복구** (`월간보고서.hwp`) |
| **윈도우에서 안 열림** | `\ / : * ? " < > \|`, 예약어(`CON`), 끝 공백·마침표는 윈도우에서 금지됩니다. | 안전한 문자로 **치환** |

> 💡 맥은 NFD 파일명도 화면에서 조합해 보여주기 때문에, 정작 본인 눈에는 멀쩡해
> 보입니다. JamoFix는 미리보기에서 `ㅎㅏㄴㄱㅡㄹ.txt`처럼 **분리된 실제 모습**을
> 보여주어 무엇을 왜 고치는지 명확히 합니다.

## 주요 기능

- 🔍 **폴더 상시 감시** — FSEvents 기반. 등록한 폴더에 새 파일이 생기면 즉시 검사 (CPU 부담 거의 없음)
- ⚡ **자동/수동 정책 분리** — NFD 정규화는 안전하므로 자동, 인코딩 복구는 오탐 방지를 위해 기본 수동 확인
- 👀 **Dry-run 미리보기** — 변경 전 → 변경 후를 보여주고 승인 후 실행
- ↩️ **되돌리기** — 모든 변경이 기록되고 원클릭 복원
- 🔀 **충돌 처리** — 같은 이름이 이미 있으면 ` (1)` 부여, APFS 정규화-무시 특성은 안전하게 우회
- 🎛 **메뉴바 토글** — 전체/폴더별 켜고 끄기
- 🔔 **알림 & 자동 시작** — 백그라운드 수정 알림, 로그인 시 자동 실행
- 🫥 **표시 옵션** — 메뉴바(상단) 아이콘·Dock(하단) 아이콘을 각각 숨겨 조용히 상주 (최소 하나는 유지)
- 🌐 **한/영 지원** — macOS 시스템 언어에 따라 UI가 자동 전환

## 스크린샷
| Preview | Setting |
|---|---|
| ![Preview](docs/images/screenshot-preview.png) | ![Setting](docs/images/screenshot-setting.png) |


## 설치

### DMG로 설치 (권장)

1. [Releases](../../releases)에서 최신 `JamoFix-x.y.z.dmg` 다운로드
2. DMG를 열고 **JamoFix.app을 Applications로 드래그**
3. 실행 (첫 실행 시 Gatekeeper 경고가 뜨면 **우클릭 → 열기**)

> ad-hoc 서명이라 다른 맥에서는 경고가 뜹니다. 정식 배포는 Apple Developer ID 서명
> + 공증(notarization)이 필요합니다.

### 소스에서 빌드

```bash
git clone <이 저장소 주소>
cd JamoFix
swift run                     # 개발 실행
swift run jamofix-selftest    # 코어 로직 테스트 (Xcode 불필요)
Scripts/package.sh            # dist/ 아래에 .app + DMG 생성
```

## 사용법

1. **폴더 탭 → "폴더 추가"** 로 감시할 폴더 등록 (다운로드, 작업 폴더 등)
2. 자소분리된 파일이 생기면 → **즉시 자동으로 NFC 정규화**
3. `¿ù°£º¸°í¼­.hwp` 같은 깨진 이름이 발견되면 → **확인 대기 탭**에서 복구안 확인 후 승인
4. 실수로 바뀐 게 있으면 → **히스토리 탭**에서 되돌리기
5. 잠시 끄려면 → 메뉴바 **한** 아이콘 → "파일명 감시" 토글

> 다운로드·데스크탑·문서 폴더를 등록하면 macOS 권한 팝업이 뜹니다 — 허용해 주세요.

## 동작 원리 (핵심)

macOS의 파일명 정규화는 함정이 많습니다. JamoFix가 실제로 부딪혀 해결한 것들:

- **`FileManager.moveItem`과 `URL` 경로 API는 파일명을 NFD로 되분해합니다.** 순진하게
  구현하면 "고쳤는데 여전히 자소분리" 상태가 됩니다. → POSIX `renamex_np`를 직접 호출해
  NFC 바이트를 그대로 씁니다.
- **APFS는 정규화를 무시하고 조회합니다.** 같은 파일의 NFD→NFC는 임시 이름을 경유한
  2단계 rename으로 처리합니다.
- **FSEvents는 rename 이전의 NFD 경로로 이벤트를 줍니다.** 이걸 그대로 믿으면 같은 파일을
  무한히 다시 고치는 루프가 생깁니다. → 디스크의 실제 엔트리 이름을 재검증합니다.

## License

MIT
