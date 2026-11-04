#!/bin/bash
# Sourced only from the local, trusted package. State files contain data, not shell code.
set -eu
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$KIT_DIR/state"

fail() { printf '%s\n' "$*" >&2; exit 1; }
hash_file() { shasum -a 256 "$1" | cut -d ' ' -f 1; }
game_running() { pgrep -x Cyberpunk2077 >/dev/null 2>&1; }

require_mac() {
  [ "$(uname -s)" = Darwin ] || fail "맥에서 실행해 주세요."
}

load_state() {
  [ -f "$STATE_DIR/game-dir.txt" ] || fail "먼저 INSTALL.command로 시험 준비를 실행해 주세요."
  IFS= read -r GAME_DIR < "$STATE_DIR/game-dir.txt"
  CACHE_FILE="$GAME_DIR/r6/cache/final.redscripts"
  INFO_FILE="$GAME_DIR/Cyberpunk2077.app/Contents/Info.plist"
  [ -f "$CACHE_FILE" ] && [ -f "$INFO_FILE" ] || fail "게임 파일을 찾지 못했습니다."
}

check_build() {
  [ "$(hash_file "$INFO_FILE")" = "$(cat "$STATE_DIR/game-info.sha256")" ] || fail "게임 버전 정보가 달라졌습니다. 캐시를 교체하지 않았습니다."
}

acquire_lock() {
  mkdir -p "$STATE_DIR"
  if ! mkdir "$STATE_DIR/run.lock" 2>/dev/null; then
    if [ -f "$STATE_DIR/run.lock/pid" ]; then
      IFS= read -r LOCK_PID < "$STATE_DIR/run.lock/pid"
      case "$LOCK_PID" in ''|*[!0-9]*) fail "잘못된 잠금 정보입니다. 상태 폴더를 확인해 주세요.";; esac
      if kill -0 "$LOCK_PID" 2>/dev/null; then
        fail "다른 아담 시험 작업이 실행 중입니다. 열린 터미널을 확인해 주세요."
      fi
      rm "$STATE_DIR/run.lock/pid"
      rmdir "$STATE_DIR/run.lock"
      mkdir "$STATE_DIR/run.lock" || fail "다른 작업이 시작됐습니다."
    else
      fail "다른 작업이 준비 중입니다. 잠시 후 다시 실행해 주세요."
    fi
  fi
  printf '%s\n' "$$" > "$STATE_DIR/run.lock/pid"
}

release_lock() {
  rm -f "$STATE_DIR/run.lock/pid"
  rmdir "$STATE_DIR/run.lock" 2>/dev/null || true
}

