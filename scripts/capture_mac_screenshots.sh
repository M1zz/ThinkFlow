#!/bin/zsh
# 맥 스토어 스크린샷 — 언어마다 그 언어 화면으로 2560×1600 네 장.
# 사용: scripts/capture_mac_screenshots.sh [언어 …]   (없으면 deploy.env 의 LOCALES 전부)
# 디버그 빌드를 예시 데이터(-ScreenshotSeed)로 띄우고, 창을 1280×800 에 맞춰 맨 앞에 올린 뒤 창 자리만 찍는다.
# mac_window_shot.py 가 이 앱의 창만 찍는다(붙은 시트 포함, 뒤 화면은 안 담김).
# ⚠️ 찍는 동안 화면을 쓴다. 자리를 비웠을 때 돌린다.
set -u
REPO=${0:A:h:h}
cd $REPO
APP=$REPO/build/dd-mac/Build/Products/Debug/ThinkFlow.app
OUT=$REPO/docs/screenshots/marketing
C=~/Library/Containers/com.leeo.thinkflow/Data/tmp; mkdir -p $C
LANGS=(${@:-${(s:,:)$(grep ^LOCALES= deploy.env | cut -d= -f2)}})
SCENES=(home:01-mac-home continue:02-mac-continue bridge:03-mac-bridge dump:04-mac-dump)
X=60; Y=60; W=1280; H=800

xcodebuild build -project ThinkFlow.xcodeproj -scheme ThinkFlow -destination 'platform=macOS' \
  -derivedDataPath build/dd-mac -allowProvisioningUpdates -quiet || exit 1

quit_app() { pkill -f "dd-mac/Build/Products/Debug/ThinkFlow.app/Contents/MacOS" 2>/dev/null; sleep 1.5; }
for lang in $LANGS; do
  mkdir -p $OUT/$lang
  for pair in $SCENES; do
    scene=${pair%%:*}; name=${pair##*:}
    quit_app
    python3 scripts/screenshot_seed.py $lang $scene $C/seed.json >/dev/null
    open -n "$APP" --args -ApplePersistenceIgnoreState YES -AppleLanguages "($lang)" -AppleLocale "$lang" \
      -ScreenshotSeed $C/seed.json -ScreenshotScene $scene
    sleep 6
    P=$(pgrep -f "dd-mac/Build/Products/Debug/ThinkFlow.app/Contents/MacOS")
    osascript -e "tell application \"System Events\" to tell (first process whose unix id is $P)" \
              -e "set frontmost to true" -e "set position of window 1 to {$X, $Y}" -e "set size of window 1 to {$W, $H}" -e "end tell" >/dev/null
    sleep 2.5
    # 창 자리를 통째로 찍으면 뒤에 있는 다른 창이 비친다 — 이 앱의 창만 찍는다.
    python3 scripts/mac_window_shot.py $P $OUT/$lang/$name.png | sed "s|^|$lang/|"
  done
done
quit_app
