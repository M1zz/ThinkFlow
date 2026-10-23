#!/bin/sh
# 스토어 스크린샷 원본을 찍는다. 손으로 몰지 않는다.
#
#   sh scripts/take_screenshots.sh <기기 UDID> <언어...>
#   예) sh scripts/take_screenshots.sh 2F236138-4FFE-4817-993C-EC31DF762C38 en ja
#   일부만 다시: ONLY="dump bridge" sh scripts/take_screenshots.sh <UDID> de
#
# 앞서 디버그 빌드를 그 기기에 깔아 둔다. 화면은 DEBUG 전용 실행 인자로 연다
# (ThoughtStore.swift 의 ScreenshotScene · HomeView · ContinueThinkingSheet · BrainDumpSheet 의 `#if DEBUG`).
# 예시 데이터는 scripts/screenshot_seed.py 가 언어마다 만든다.
# 원본은 docs/screenshots/raw/<언어>/ 에 1320x2868 그대로 둔다 (스토어에 안 올라감).
# 그다음 `python3 scripts/make_marketing_screenshots.py <언어>` 가 글과 목업을 입힌다.
set -e
D="$1"; shift
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BID=com.leeo.thinkflow
TMP="${TMPDIR:-/tmp}/thinkflow-shots"
mkdir -p "$TMP"

# 앱 언어 → 그 언어 사람이 쓰는 기본 키보드
keyboard() {
  case "$1" in
    ko) echo "ko_KR@sw=Korean;hw=Automatic" ;;
    en) echo "en_US@sw=QWERTY;hw=Automatic" ;;
    en-GB) echo "en_GB@sw=QWERTY;hw=Automatic" ;;
    ja) echo "ja_JP-Kana@sw=Kana;hw=Automatic" ;;
    zh-Hans) echo "zh_Hans-Pinyin@sw=Pinyin10;hw=Automatic" ;;
    zh-Hant) echo "zh_Hant-Zhuyin@sw=Zhuyin;hw=Automatic" ;;
    es) echo "es_ES@sw=QWERTY-Spanish;hw=Automatic" ;;
    de) echo "de_DE@sw=QWERTZ-German;hw=Automatic" ;;
    fr) echo "fr_FR@sw=AZERTY-French;hw=Automatic" ;;
    it) echo "it_IT@sw=QWERTY-Italian;hw=Automatic" ;;
    pt-BR) echo "pt_BR@sw=QWERTY-Portuguese-Brazil;hw=Automatic" ;;
    ru) echo "ru_RU@sw=Russian;hw=Automatic" ;;
    th) echo "th_TH@sw=Thai;hw=Automatic" ;;
    vi) echo "vi_VN@sw=Vietnamese;hw=Automatic" ;;
    cs) echo "cs_CZ@sw=QWERTZ-Czech;hw=Automatic" ;;
    da) echo "da_DK@sw=QWERTY-Danish;hw=Automatic" ;;
    el) echo "el_GR@sw=Greek;hw=Automatic" ;;
    fi) echo "fi_FI@sw=QWERTY-Finnish;hw=Automatic" ;;
    id) echo "id_ID@sw=QWERTY;hw=Automatic" ;;
    nb) echo "nb_NO@sw=QWERTY-Norwegian;hw=Automatic" ;;
    nl) echo "nl_NL@sw=QWERTY-Dutch;hw=Automatic" ;;
    pl) echo "pl_PL@sw=QWERTY-Polish;hw=Automatic" ;;
    sv) echo "sv_SE@sw=QWERTY-Swedish;hw=Automatic" ;;
    tr) echo "tr_TR@sw=QWERTY-Turkish;hw=Automatic" ;;
  esac
}

# 지역: 날짜 표기(예: en-GB 는 일/월)가 그 나라 것이 되게
region() {
  case "$1" in
    ko) echo ko_KR ;; en) echo en_US ;; en-GB) echo en_GB ;; ja) echo ja_JP ;;
    zh-Hans) echo zh_CN ;; zh-Hant) echo zh_TW ;; es) echo es_ES ;; de) echo de_DE ;;
    fr) echo fr_FR ;; it) echo it_IT ;; pt-BR) echo pt_BR ;; ru) echo ru_RU ;;
    th) echo th_TH ;; vi) echo vi_VN ;; cs) echo cs_CZ ;; da) echo da_DK ;;
    el) echo el_GR ;; fi) echo fi_FI ;; id) echo id_ID ;; nb) echo nb_NO ;;
    nl) echo nl_NL ;; pl) echo pl_PL ;; sv) echo sv_SE ;; tr) echo tr_TR ;;
  esac
}

xcrun simctl boot "$D" 2>/dev/null || true
xcrun simctl bootstatus "$D" >/dev/null 2>&1 || true
xcrun simctl ui "$D" appearance light
xcrun simctl status_bar "$D" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --dataNetwork wifi >/dev/null 2>&1 || true

for L in "$@"; do
  OUT="$ROOT/docs/screenshots/raw/$L"
  mkdir -p "$OUT"
  KB="$(keyboard "$L")"; RG="$(region "$L")"
  shot() {  # 파일 이름 · 장면
    if [ -n "$ONLY" ]; then case " $ONLY " in *" $2 "*) ;; *) return 0 ;; esac; fi
    python3 "$ROOT/scripts/screenshot_seed.py" "$L" "$2" "$TMP/seed-$L-$2.json"
    xcrun simctl terminate "$D" $BID 2>/dev/null || true
    sleep 1
    xcrun simctl launch "$D" $BID -AppleLanguages "($L)" -AppleLocale "$RG" \
      -AppleKeyboards "(\"$KB\")" \
      -ScreenshotSeed "$TMP/seed-$L-$2.json" -ScreenshotScene "$2" >/dev/null
    sleep 8
    xcrun simctl io "$D" screenshot --type=png "$OUT/$1" >/dev/null 2>&1
    echo "  $L $1"
  }
  shot 01-home.png     home
  shot 02-continue.png continue
  shot 03-bridge.png   bridge
  shot 04-thread.png   thread
  shot 05-dump.png     dump
done
xcrun simctl terminate "$D" $BID 2>/dev/null || true
