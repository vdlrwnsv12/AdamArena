#!/bin/bash
set -eu
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$KIT_DIR/common.sh"
require_mac
game_running && fail "게임을 완전히 종료해 주세요."
acquire_lock
trap release_lock EXIT
if [ -f "$STATE_DIR/game-dir.txt" ]; then
  fail "이미 준비된 시험본입니다. PLAY.command를 실행해 주세요. 새 준비는 새로 압축을 푼 폴더에서 진행하세요."
fi
GAME_DIR="${1:-$HOME/Library/Application Support/Steam/steamapps/common/Cyberpunk 2077}"
CACHE_FILE="$GAME_DIR/r6/cache/final.redscripts"
INFO_FILE="$GAME_DIR/Cyberpunk2077.app/Contents/Info.plist"
[ -f "$CACHE_FILE" ] && [ -f "$INFO_FILE" ] || fail "게임 폴더 또는 캐시를 찾지 못했습니다."
[ ! -L "$CACHE_FILE" ] || fail "캐시가 심볼릭 링크입니다. 자동 교체를 중단했습니다."
GAME_INFO_HASH="$(hash_file "$INFO_FILE")"
if ! GAME_LIBRARIES="$(otool -L "$GAME_DIR/Cyberpunk2077.app/Contents/MacOS/Cyberpunk2077" 2>&1)"; then
  printf '%s\n' "$GAME_LIBRARIES"
  fail "게임 라이브러리 확인 실패. 이 출력을 보내 주세요."
fi
if printf '%s\n' "$GAME_LIBRARIES" | grep -Ei 'libcp77_console|nightcity|night.city' >/dev/null; then
  fail "게임에 콘솔 런타임 연결이 남아 있습니다. 원본 실행파일 복구를 확인해 주세요."
fi
BUILD_DIR="$(mktemp -d "$STATE_DIR/build.XXXXXX")"
mkdir -p "$BUILD_DIR/r6/scripts/AdamArena" "$BUILD_DIR/r6/cache" "$BUILD_DIR/r6/logs"
cp -p "$CACHE_FILE" "$BUILD_DIR/baseline.redscripts"
BASELINE_HASH="$(hash_file "$BUILD_DIR/baseline.redscripts")"
cp -p "$BUILD_DIR/baseline.redscripts" "$BUILD_DIR/r6/cache/final.redscripts"
cp "$KIT_DIR/source/AdamArena.reds" "$BUILD_DIR/r6/scripts/AdamArena/AdamArena.reds"
chmod u+x "$KIT_DIR/tools/scc"
xattr -d com.apple.quarantine "$KIT_DIR/tools/scc" 2>/dev/null || true
xattr -d com.apple.quarantine "$KIT_DIR/tools/libscc_lib.dylib" 2>/dev/null || true
echo "별도 작업 폴더에서 아담 모드 한 파일만 컴파일합니다."
if ! "$KIT_DIR/tools/scc" -compile "$BUILD_DIR/r6/scripts" > "$STATE_DIR/compile.log" 2>&1; then
  cat "$STATE_DIR/compile.log"
  fail "컴파일 실패. 게임 캐시는 교체하지 않았습니다. state/compile.log를 보내 주세요."
fi
[ -s "$BUILD_DIR/r6/cache/final.redscripts" ] || fail "컴파일 출력이 없습니다."
[ "$(dd if="$BUILD_DIR/r6/cache/final.redscripts" bs=4 count=1 2>/dev/null)" = "REDS" ] || fail "컴파일 출력 헤더가 올바르지 않습니다. state/compile.log를 보내 주세요. 게임 원본 캐시는 변경하지 않았습니다."
grep -Fq 'Compilation complete' "$STATE_DIR/compile.log" || fail "컴파일 완료 기록이 없습니다. state/compile.log를 보내 주세요."
[ "$(hash_file "$CACHE_FILE")" = "$BASELINE_HASH" ] || fail "준비 중 게임 캐시가 변경됐습니다. 교체하지 않았습니다."
[ "$(hash_file "$INFO_FILE")" = "$GAME_INFO_HASH" ] || fail "준비 중 게임 버전 정보가 변경됐습니다."
[ "$(hash_file "$BUILD_DIR/r6/cache/final.redscripts")" != "$BASELINE_HASH" ] || fail "컴파일 결과가 원본과 같습니다. 모드 반영 여부를 확인해야 합니다."
cp -p "$BUILD_DIR/baseline.redscripts" "$STATE_DIR/baseline.redscripts"
cp -p "$BUILD_DIR/r6/cache/final.redscripts" "$STATE_DIR/candidate.redscripts"
printf '%s\n' "$BASELINE_HASH" > "$STATE_DIR/baseline.sha256"
hash_file "$STATE_DIR/candidate.redscripts" > "$STATE_DIR/candidate.sha256"
printf '%s\n' "$GAME_INFO_HASH" > "$STATE_DIR/game-info.sha256"
hash_file "$KIT_DIR/source/AdamArena.reds" > "$STATE_DIR/source.sha256"
printf '%s\n' "$GAME_DIR" > "$STATE_DIR/game-dir.txt"
echo "아담 단독 시험본 준비 완료. 이 단계에서는 게임 캐시를 교체하지 않았습니다."
echo "스팀을 켜서 로그인한 뒤 PLAY.command로 시험하세요."
