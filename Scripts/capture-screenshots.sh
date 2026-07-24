#!/bin/bash
# README용 스크린샷 캡처 도우미.
# 실행하면 창을 클릭해 캡처하는 모드로 들어가고, 캡처한 이미지를
# docs/images/ 아래 올바른 파일명으로 저장한다.
#
# 사용법:
#   1. 먼저 앱을 실행: open dist/JamoFix.app  (또는 swift run)
#   2. 이 스크립트 실행 후 안내에 따라 각 화면을 클릭해서 캡처
set -euo pipefail
cd "$(dirname "$0")/.."

shots=(
    "screenshot-folders:폴더 탭(감시 폴더 목록)을 클릭하세요"
    "screenshot-preview:미리보기 시트 또는 확인 대기 탭을 클릭하세요"
    "screenshot-menubar:메뉴바 드롭다운(한 아이콘 클릭한 상태)을 클릭하세요"
)

for entry in "${shots[@]}"; do
    file="${entry%%:*}"
    hint="${entry#*:}"
    echo ""
    echo "▸ $hint"
    echo "  (창 위로 마우스를 올리고 클릭 — 취소하려면 Esc)"
    # -o: 창 그림자 제거, -w: 창 선택 모드
    screencapture -o -w "docs/images/$file.png"
    echo "  저장됨: docs/images/$file.png"
done

echo ""
echo "완료. README의 자리표시자가 실제 캡처로 교체되었습니다."
