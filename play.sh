#!/bin/bash
set -eu
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$KIT_DIR/common.sh"
require_mac
load_state
game_running && fail "게임을 종료한 뒤 시험을 시작해 주세요."
acquire_lock
trap release_lock EXIT
exec > >(tee "$STATE_DIR/play.log") 2>&1
check_build
[ "$(hash_file "$CACHE_FILE")" = "$(cat "$STATE_DIR/baseline.sha256")" ] || fail "게임 캐시가 준비 당시와 다릅니다. 새 시험본을 준비해 주세요."
[ "$(hash_file "$STATE_DIR/candidate.redscripts")" = "$(cat "$STATE_DIR/candidate.sha256")" ] || fail "시험 캐시가 변경됐습니다."
[ "$(hash_file "$KIT_DIR/source/AdamArena.reds")" = "$(cat "$STATE_DIR/source.sha256")" ] || fail "소스가 준비 후 변경됐습니다. 새 시험본을 준비해 주세요."
echo "아담 시험판 0.6.7: 지정한 스크립트 파일로 게임을 실행합니다."
echo "스팀이 실행 중이고 로그인돼 있어야 합니다."
printf '스크립트 인자: %s\n' "-scriptsBlobPath=$STATE_DIR/candidate.redscripts"
# The macOS 2.5 loader passes this option as one argument, with an equals sign.
# SteamAppId is required for direct execution of the Steam game build.
cd "$GAME_DIR"
result=0
env -u DYLD_INSERT_LIBRARIES -u DYLD_FORCE_FLAT_NAMESPACE \
  SteamAppId=1091500 SteamGameId=1091500 \
  "$GAME_DIR/Cyberpunk2077.app/Contents/MacOS/Cyberpunk2077" \
  "-scriptsBlobPath=$STATE_DIR/candidate.redscripts" \
  > "$STATE_DIR/game.log" 2>&1 || result=$?
printf '게임 종료 코드: %s\n' "$result"
if [ "$result" -ne 0 ]; then
  tail -n 30 "$STATE_DIR/game.log"
  echo "실행 실패. state/game.log와 state/play.log를 보내 주세요."
fi
if [ "$(hash_file "$CACHE_FILE")" != "$(cat "$STATE_DIR/baseline.sha256")" ]; then
  echo "게임 기본 캐시가 준비 당시와 달라졌습니다. 변경 원인을 확인해야 합니다."
fi
exit "$result"
