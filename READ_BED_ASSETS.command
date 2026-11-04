#!/bin/bash
set -eu
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3를 찾지 못했습니다. 이 메시지를 알려 주세요."
  exit 1
fi
echo "침대 장면 확인용 파일을 복사합니다. 게임 파일은 변경하지 않습니다."
python3 "$KIT_DIR/tools/bed_asset_collector.py" "$@"
echo "창을 닫으려면 Enter를 누르세요."
read -r _
