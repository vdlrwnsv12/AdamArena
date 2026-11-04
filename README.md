# 아담 투기장 (Adam Arena) — 악몽 리허설

> 🍎 **macOS + Steam 판 전용 모드입니다.** Windows, GOG, Epic, 콘솔 판은 지원하지 않습니다.

사이버펑크 2077용 redscript 모드입니다. 집 침대 대화에 **"아담과 싸우기 — 악몽 리허설"** 항목을 추가해, 꿈속에서 미코시 보스 방의 아담 스매셔와 반복 전투를 할 수 있게 합니다.

> ⚠️ **시험판(0.6.6)** — 컴파일과 로직 검사는 통과했지만, 실제 게임에서의 표시·입력·이동·소환·복귀는 아직 충분히 검증되지 않았습니다. 반드시 **별도 저장본**으로 시험하세요.

## 주요 기능
- 기본 침대 대화 UI에 전투 항목 추가 (휠/방향키로 선택, F로 실행)
- 꿈속 보스 방 이동 → 스매셔 소환, 패배 시 치명상 방지 후 침대 곁으로 복귀
- 격파 후 또는 전투 중 **G**로 종료, 체력·스태미나는 입장 전 값으로 복원
- 사이버웨어 용량 초과 벌칙 (운반 한도·스태미나 비용·이동 제한)
- 특성 화면의 "특전·특성 모두 초기화" 버튼 지원 (확인 시에만)

자세한 내용은 [`사용법.txt`](사용법.txt), 검증 범위는 [`검증.txt`](검증.txt)를 보세요.

## 요구 사항
- **macOS** (Apple Silicon)
- **Steam 판** Cyberpunk 2077 2.5 (기본 스팀 라이브러리 경로)
- redscript 0.5.32 (키트에 포함, 별도 설치 불필요)

## 설치

1. [Releases](../../releases)에서 `AdamArena-0.6.6-macOS.zip`을 받아 새 폴더에 풉니다.
2. 인터넷에서 받은 파일이라 macOS가 실행을 막으면, 터미널에서 다음 명령을 실행합니다:
   `xattr -dr com.apple.quarantine <압축 푼 폴더>`
3. 게임을 완전히 종료한 뒤 `INSTALL.command` → `PLAY.command` 순서로 실행합니다.
   - 게임 원본 캐시를 교체하지 않고, 별도로 컴파일한 스크립트로 게임을 실행합니다.
   - 스팀 일반 실행으로는 모드가 적용되지 않습니다.

## 문제 신고
[Issues](../../issues)에 증상과 함께 `state/compile.log`, `state/play.log`, `state/game.log`를 첨부해 주세요.

---

## English (short)
A redscript mod for Cyberpunk 2077 that adds a "Fight Adam — Nightmare Rehearsal" option to V's bed dialog, letting you repeatedly fight Adam Smasher in a dream arena. **macOS + Steam version only. Experimental build (0.6.6), Korean UI only (game 2.5, redscript 0.5.32 bundled).** Use a separate save.
Install: unzip `AdamArena-0.6.6-macOS.zip`, run `INSTALL.command`, then `PLAY.command`. Windows / GOG / Epic / consoles are not supported.

## 크레딧
- 컴파일러: [redscript](https://github.com/jac3km4/redscript) v0.5.32 (MIT, [`tools/REDSCRIPT-LICENSE`](tools/REDSCRIPT-LICENSE))
- Cyberpunk 2077 © CD PROJEKT RED. 이 저장소에는 게임 원본 파일이 포함되어 있지 않습니다.
