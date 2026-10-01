#!/bin/zsh

set -euo pipefail

print -u2 -- "ERROR: この撮影契約は旧30秒ミッションUI専用のため廃止しました。Field Notebook用の状態遷移とOCR契約を実装してから再有効化してください。"
exit 2

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
app_dir="$repo_root/app"
shots_root="$repo_root/docs/store-shots-2026"
bundle_id="jp.dekisugi.dekisugi"
android_avd="Pixel_API36"
android_sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb_bin="$android_sdk/platform-tools/adb"
emulator_bin="$android_sdk/emulator/emulator"
ios_app="$app_dir/build/ios/iphonesimulator/Runner.app"
android_apk="$app_dir/build/app/outputs/flutter-apk/app-debug.apk"
inspector_source="$repo_root/tools/inspect-store-shot.swift"
flattener_source="$repo_root/tools/flatten-store-shot.swift"
build_assets=1
verify_only=0
capture_ios_assets=1
capture_android_assets=1

usage() {
  print -- "Usage: tools/capture-store-shots.sh [--skip-build] [--ios-only | --android-only]"
  print -- "       tools/capture-store-shots.sh --verify-only"
  print -- ""
  print -- "Captures the current first-run UI on dedicated iOS simulators and"
  print -- "the Pixel_API36 Android emulator, then validates store dimensions."
}

while (( $# > 0 )); do
  case "$1" in
    --skip-build)
      build_assets=0
      ;;
    --verify-only)
      verify_only=1
      ;;
    --ios-only)
      capture_android_assets=0
      ;;
    --android-only)
      capture_ios_assets=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      print -u2 -- "Unknown option: $1"
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if (( verify_only )); then
  exec "$repo_root/tools/verify-store-shots.sh" "$shots_root"
fi

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    print -u2 -- "Required command not found: $1"
    exit 1
  }
}

require_command flutter
require_command xcrun
require_command python3
[[ -f "$inspector_source" ]] || { print -u2 -- "Missing image inspector: $inspector_source"; exit 1; }
[[ -f "$flattener_source" ]] || { print -u2 -- "Missing image flattener: $flattener_source"; exit 1; }
if (( capture_android_assets )); then
  [[ -x "$adb_bin" ]] || { print -u2 -- "adb not found: $adb_bin"; exit 1; }
  [[ -x "$emulator_bin" ]] || { print -u2 -- "emulator not found: $emulator_bin"; exit 1; }
fi

temp_base="${TMPDIR:-/tmp}"
work_dir="$(mktemp -d "$temp_base/dekisugi-store-shots.XXXXXX")"
inspector_bin="$work_dir/inspect-store-shot"
flattener_bin="$work_dir/flatten-store-shot"
android_serial=""
started_android=0
android_size_overridden=0
android_battery_overridden=0
android_wifi_was_on=""
android_policy_control=""
android_system_ui_overridden=0
shipaton_udid=""
created_shipaton=0

cleanup() {
  local exit_code="$?"
  trap - EXIT INT TERM

  if [[ -n "$android_serial" ]]; then
    "$adb_bin" -s "$android_serial" shell rm -f /sdcard/dekisugi-store-shot-window.xml \
      >/dev/null 2>&1 || true
    if (( android_size_overridden )); then
      "$adb_bin" -s "$android_serial" shell wm size reset >/dev/null 2>&1 || true
    fi
    if (( android_battery_overridden )); then
      "$adb_bin" -s "$android_serial" shell dumpsys battery reset >/dev/null 2>&1 || true
    fi
    if [[ "$android_wifi_was_on" == "1" ]]; then
      "$adb_bin" -s "$android_serial" shell svc wifi enable >/dev/null 2>&1 || true
    fi
    if (( android_system_ui_overridden )); then
      if [[ -n "$android_policy_control" && "$android_policy_control" != "null" ]]; then
        "$adb_bin" -s "$android_serial" shell settings put global policy_control \
          "$android_policy_control" >/dev/null 2>&1 || true
      else
        "$adb_bin" -s "$android_serial" shell settings delete global policy_control \
          >/dev/null 2>&1 || true
      fi
    fi
    if (( started_android )); then
      "$adb_bin" -s "$android_serial" emu kill >/dev/null 2>&1 || true
    fi
  fi

  if (( created_shipaton )) && [[ -n "$shipaton_udid" ]]; then
    xcrun simctl shutdown "$shipaton_udid" >/dev/null 2>&1 || true
    xcrun simctl delete "$shipaton_udid" >/dev/null 2>&1 || true
  fi

  if [[ -n "$work_dir" && "$work_dir" == "$temp_base"/dekisugi-store-shots.* ]]; then
    rm -rf -- "$work_dir"
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

mkdir -p \
  "$shots_root/app-store/iphone-6.9" \
  "$shots_root/app-store/ipad-13" \
  "$shots_root/shipaton/iphone-1179x2556" \
  "$shots_root/google-play/phone"

xcrun swiftc "$inspector_source" -o "$inspector_bin"
xcrun swiftc "$flattener_source" -o "$flattener_bin"

if (( build_assets )); then
  print -- "Building current Flutter UI for simulator capture..."
  (
    cd "$app_dir"
    if (( capture_ios_assets )); then
      flutter build ios --simulator --debug
    fi
    if (( capture_android_assets )); then
      flutter build apk --debug
    fi
  )
fi

if (( capture_ios_assets )); then
  [[ -d "$ios_app" ]] || { print -u2 -- "Missing iOS simulator app: $ios_app"; exit 1; }
fi
if (( capture_android_assets )); then
  [[ -f "$android_apk" ]] || { print -u2 -- "Missing Android debug APK: $android_apk"; exit 1; }
fi

find_ios_udid() {
  local device_name="$1"
  local line
  line="$(xcrun simctl list devices available | grep -F "    $device_name (" | sed -n '1p')"
  [[ -n "$line" ]] || { print -u2 -- "iOS simulator not found: $device_name"; return 1; }
  print -r -- "$line" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

capture_ios_udid() {
  local device_name="$1"
  local udid="$2"
  local output_file="$3"

  print -- "Capturing $device_name..."
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl ui "$udid" appearance light
  xcrun simctl ui "$udid" content_size large
  xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
  xcrun simctl status_bar "$udid" override \
    --time 9:41 \
    --dataNetwork wifi \
    --wifiMode active \
    --wifiBars 3 \
    --cellularMode active \
    --cellularBars 4 \
    --batteryState charged \
    --batteryLevel 100
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$ios_app"
  xcrun simctl launch "$udid" "$bundle_id" >/dev/null

  # A first boot can show a system "Ready for Apple Intelligence" banner, and
  # a newly created simulator can remain on the launch screen for several
  # seconds. Capture to a temporary file until OCR proves that the current
  # first mission is visible and the system banner is gone. Invalid frames
  # never replace a previously verified output.
  local raw_candidate="$work_dir/ios-raw-${udid}.png"
  local candidate="$work_dir/ios-candidate-${udid}.png"
  local ready=0
  for _ in {1..30}; do
    sleep 2
    xcrun simctl io "$udid" screenshot --mask=ignored "$raw_candidate" >/dev/null
    "$flattener_bin" "$raw_candidate" "$candidate" F6F2E9
    if "$inspector_bin" "$candidate" \
      --require "30秒おためしミッション" \
      --forbid "Ready for Apple Intelligence" \
      --forbid "Time to experience the new personal intelligence system" \
      --corner-rgb F6F2E9 \
      >/dev/null 2>&1; then
      ready=1
      break
    fi
  done
  (( ready )) || {
    print -u2 -- "Current UI did not become cleanly capturable on $device_name"
    "$inspector_bin" "$candidate" \
      --require "30秒おためしミッション" \
      --forbid "Ready for Apple Intelligence" \
      --forbid "Time to experience the new personal intelligence system" \
      --corner-rgb F6F2E9 \
      || true
    exit 1
  }
  mv -f "$candidate" "$output_file"
}

if (( capture_ios_assets )); then
  iphone_udid="$(find_ios_udid "iPhone 17 Pro Max")"
  ipad_udid="$(find_ios_udid "iPad Pro 13-inch (M5)")"
  capture_ios_udid \
    "iPhone 17 Pro Max" "$iphone_udid" \
    "$shots_root/app-store/iphone-6.9/01-first-mission-predict.png"
  capture_ios_udid \
    "iPad Pro 13-inch (M5)" "$ipad_udid" \
    "$shots_root/app-store/ipad-13/01-first-mission-predict.png"

  # Shipaton's upload field is a separate contract from either store: it requires
  # exactly 1179x2556 without a device frame. An iPhone 15 Pro simulator emits
  # that framebuffer natively, so no stretching, crop, or marketing canvas is used.
  runtime_id="$(xcrun simctl list runtimes available -j | python3 -c '
import json
import sys

runtimes = [
    item for item in json.load(sys.stdin)["runtimes"]
    if item.get("isAvailable") and item.get("platform") == "iOS"
]
if not runtimes:
    raise SystemExit("No available iOS simulator runtime")
runtimes.sort(key=lambda item: tuple(int(part) for part in item["version"].split(".")))
print(runtimes[-1]["identifier"])
')"
  shipaton_udid="$(xcrun simctl create \
    "Dekisugi Shipaton Capture $$" \
    com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro \
    "$runtime_id")"
  created_shipaton=1
  capture_ios_udid \
    "Shipaton iPhone 15 Pro" "$shipaton_udid" \
    "$shots_root/shipaton/iphone-1179x2556/01-first-mission-predict.png"
fi

find_android_serial() {
  local serial
  local avd_name
  for serial in ${(f)"$($adb_bin devices | awk '$1 ~ /^emulator-/ && $2 == "device" { print $1 }')"}; do
    avd_name="$($adb_bin -s "$serial" emu avd name 2>/dev/null | tr -d '\r' | sed -n '1p')"
    if [[ "$avd_name" == "$android_avd" ]]; then
      print -r -- "$serial"
      return 0
    fi
  done
  return 1
}

if (( capture_android_assets )); then
android_serial="$(find_android_serial || true)"
if [[ -z "$android_serial" ]]; then
  print -- "Starting Android emulator $android_avd..."
  "$emulator_bin" \
    -avd "$android_avd" \
    -no-window \
    -no-audio \
    -no-boot-anim \
    -no-snapshot-save \
    >"$work_dir/android-emulator.log" 2>&1 &
  started_android=1

  for _ in {1..120}; do
    android_serial="$(find_android_serial || true)"
    [[ -n "$android_serial" ]] && break
    sleep 1
  done
fi

[[ -n "$android_serial" ]] || {
  print -u2 -- "Android emulator did not appear. Log: $work_dir/android-emulator.log"
  exit 1
}

for _ in {1..120}; do
  boot_completed="$($adb_bin -s "$android_serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  [[ "$boot_completed" == "1" ]] && break
  sleep 1
done
[[ "${boot_completed:-}" == "1" ]] || { print -u2 -- "Android emulator boot timed out"; exit 1; }

print -- "Capturing Google Play phone flow on $android_serial..."
android_wifi_was_on="$($adb_bin -s "$android_serial" shell settings get global wifi_on | tr -d '\r')"
android_policy_control="$($adb_bin -s "$android_serial" shell settings get global policy_control | tr -d '\r')"
android_system_ui_overridden=1
"$adb_bin" -s "$android_serial" shell wm size 1080x1920 >/dev/null
android_size_overridden=1
"$adb_bin" -s "$android_serial" shell svc wifi disable >/dev/null
"$adb_bin" -s "$android_serial" shell dumpsys battery set level 100 >/dev/null
"$adb_bin" -s "$android_serial" shell dumpsys battery set ac 1 >/dev/null
android_battery_overridden=1
"$adb_bin" -s "$android_serial" shell settings put global policy_control \
  'immersive.navigation=*' >/dev/null
"$adb_bin" -s "$android_serial" install -r "$android_apk" >/dev/null
"$adb_bin" -s "$android_serial" shell pm clear "$bundle_id" >/dev/null
"$adb_bin" -s "$android_serial" shell am start \
  -n "$bundle_id/.MainActivity" >/dev/null
sleep 4

foreground="$($adb_bin -s "$android_serial" shell dumpsys activity activities \
  | grep -E 'topResumedActivity|mResumedActivity' \
  | sed -n '1p')"
[[ "$foreground" == *"$bundle_id"* ]] || {
  print -u2 -- "Expected $bundle_id in foreground, got: $foreground"
  exit 1
}

capture_android_jpeg() {
  local filename="$1"
  shift
  local png="$work_dir/$filename.png"
  local candidate="$work_dir/$filename.jpg"
  local ready=0

  # Capture to the temporary directory until OCR proves that the requested
  # current-UI phase is visible. A launch frame or partially transitioned
  # screen never replaces a previously verified store asset.
  for _ in {1..15}; do
    "$adb_bin" -s "$android_serial" exec-out screencap -p > "$png"
    /usr/bin/sips -s format jpeg -s formatOptions 100 "$png" \
      --out "$candidate" >/dev/null
    if "$inspector_bin" "$candidate" "$@" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done
  (( ready )) || {
    print -u2 -- "Android UI did not become cleanly capturable: $filename"
    "$inspector_bin" "$candidate" "$@" || true
    exit 1
  }
  mv -f "$candidate" "$shots_root/google-play/phone/$filename.jpg"
}

find_flutter_text_coordinates() {
  local target="$1"
  local coordinates=""
  local local_xml="$work_dir/window.xml"
  local attempts="${2:-10}"

  for (( attempt = 1; attempt <= attempts; attempt++ )); do
    "$adb_bin" -s "$android_serial" shell uiautomator dump --compressed \
      /sdcard/dekisugi-store-shot-window.xml >/dev/null 2>&1 || true
    "$adb_bin" -s "$android_serial" exec-out cat \
      /sdcard/dekisugi-store-shot-window.xml > "$local_xml" 2>/dev/null || true
    coordinates="$(python3 - "$local_xml" "$target" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

path, target = sys.argv[1:]
try:
    root = ET.parse(path).getroot()
except (ET.ParseError, OSError):
    raise SystemExit(0)

for node in root.iter("node"):
    if target not in (node.attrib.get("text"), node.attrib.get("content-desc")):
        continue
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.attrib.get("bounds", ""))
    if match:
        left, top, right, bottom = map(int, match.groups())
        print(f"{(left + right) // 2} {(top + bottom) // 2}")
        break
PY
)"
    [[ -n "$coordinates" ]] && break
    sleep 1
  done

  print -r -- "$coordinates"
}

tap_flutter_text() {
  local target="$1"
  local coordinates="$(find_flutter_text_coordinates "$target")"

  [[ -n "$coordinates" ]] || {
    print -u2 -- "Could not find Flutter semantics text: $target"
    exit 1
  }
  local x="${coordinates%% *}"
  local y="${coordinates##* }"
  "$adb_bin" -s "$android_serial" shell input tap "$x" "$y" >/dev/null
  sleep 2
}

scroll_to_and_tap_flutter_text() {
  local target="$1"
  local coordinates=""
  local size_line="$($adb_bin -s "$android_serial" shell wm size | tr -d '\r' | sed -n '$p')"
  local size="${size_line##*: }"
  local width="${size%x*}"
  local height="${size#*x}"

  [[ "$width" == <-> && "$height" == <-> ]] || {
    print -u2 -- "Could not read Android display size: $size_line"
    exit 1
  }

  for _ in {1..12}; do
    coordinates="$(find_flutter_text_coordinates "$target" 1)"
    [[ -n "$coordinates" ]] && break
    "$adb_bin" -s "$android_serial" shell input swipe \
      "$(( width / 2 ))" "$(( height * 4 / 5 ))" \
      "$(( width / 2 ))" "$(( height / 5 ))" 350 >/dev/null
    sleep 1
  done

  [[ -n "$coordinates" ]] || {
    print -u2 -- "Could not scroll to Flutter semantics text: $target"
    exit 1
  }
  local x="${coordinates%% *}"
  local y="${coordinates##* }"
  "$adb_bin" -s "$android_serial" shell input tap "$x" "$y" >/dev/null
  sleep 2
}

capture_android_jpeg "01-first-mission-predict" \
  --require "30秒おためしミッション" \
  --forbid "Ready for Apple Intelligence"
tap_flutter_text "同時に着く"
capture_android_jpeg "02-first-mission-challenge" \
  --require "デキすぎ君の思い込み" \
  --forbid "Ready for Apple Intelligence"
tap_flutter_text "違う。空気の抵抗を無視すれば、重さに関係なく同時に着く"
capture_android_jpeg "03-first-mission-clear" \
  --require "TUTORIAL CLEAR" \
  --forbid "Ready for Apple Intelligence"

# Return to a fresh, unconsented install and capture the structurally local-only
# route. The entry is found through Flutter accessibility semantics after
# proportional scroll gestures; no screen-size-specific tap coordinate is used.
"$adb_bin" -s "$android_serial" shell pm clear "$bundle_id" >/dev/null
"$adb_bin" -s "$android_serial" shell am start \
  -n "$bundle_id/.MainActivity" >/dev/null
sleep 3
scroll_to_and_tap_flutter_text "通信しない端末内モードを使う"
capture_android_jpeg "04-device-only-studio" \
  --require "答えを送らず" \
  --require "教材と概念、完了回数" \
  --forbid "Ready for Apple Intelligence"
fi

print -- "Validating generated assets..."
"$repo_root/tools/verify-store-shots.sh" "$shots_root"
