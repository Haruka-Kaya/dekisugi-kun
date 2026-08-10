#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
app_dir="$repo_root/app"
bundle_id="jp.dekisugi.dekisugi"
android_avd="Pixel_API36"
android_sdk="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
adb_bin="$android_sdk/platform-tools/adb"
emulator_bin="$android_sdk/emulator/emulator"
apk_path="$app_dir/build/app/outputs/flutter-apk/app-debug.apk"
caption_path="$repo_root/docs/shipaton-demo-captions.en.srt"
output_dir="$repo_root/docs/shipaton-demo-2026"
output_path="$output_dir/dekisugi-on-device-rehearsal.mp4"
ffmpeg_bin="${FFMPEG_BIN:-/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg}"
ffprobe_bin="${FFPROBE_BIN:-/opt/homebrew/opt/ffmpeg-full/bin/ffprobe}"
build_app=1
verify_only=0
raw_root=""

usage() {
  print -- "Usage: tools/capture-shipaton-demo-rehearsal.sh [--skip-build] [--raw-dir DIR]"
  print -- "       tools/capture-shipaton-demo-rehearsal.sh --verify-only"
  print -- ""
  print -- "Records the deterministic Android on-device route and exports a"
  print -- "110-second captioned rehearsal. It is not a public submission video."
}

while (( $# > 0 )); do
  case "$1" in
    --skip-build)
      build_app=0
      ;;
    --raw-dir)
      shift
      (( $# > 0 )) || { print -u2 -- "--raw-dir requires a path"; exit 2; }
      raw_root="${1:A}"
      ;;
    --verify-only)
      verify_only=1
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
  exec "$repo_root/tools/verify-shipaton-demo-rehearsal.sh" "$output_path"
fi

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    print -u2 -- "Required command not found: $1"
    exit 1
  }
}

require_command flutter
require_command python3
require_command shasum
[[ -x "$adb_bin" ]] || { print -u2 -- "adb not found: $adb_bin"; exit 1; }
[[ -x "$emulator_bin" ]] || { print -u2 -- "emulator not found: $emulator_bin"; exit 1; }
[[ -x "$ffmpeg_bin" ]] || {
  print -u2 -- "ffmpeg-full not found: $ffmpeg_bin"
  print -u2 -- "Install it with: brew install ffmpeg-full"
  exit 1
}
[[ -x "$ffprobe_bin" ]] || { print -u2 -- "ffprobe not found: $ffprobe_bin"; exit 1; }
[[ -f "$caption_path" ]] || { print -u2 -- "Missing captions: $caption_path"; exit 1; }
"$ffmpeg_bin" -hide_banner -filters 2>&1 | grep ' subtitles ' >/dev/null || {
  print -u2 -- "Selected ffmpeg lacks the libass subtitles filter: $ffmpeg_bin"
  exit 1
}

if [[ -z "$raw_root" ]]; then
  raw_root="$(mktemp -d "${TMPDIR:-/tmp}/dekisugi-shipaton-rehearsal-raw.XXXXXX")"
else
  [[ "$raw_root" != "$repo_root" && "$raw_root" != "$repo_root"/* ]] || {
    print -u2 -- "Raw recordings must remain outside the repository: $raw_root"
    exit 1
  }
  mkdir -p "$raw_root"
fi

mkdir -p "$output_dir" "$raw_root/normalized"

android_serial=""
started_android=0
recording_host_pid=""
recording_remote_path=""
recording_name=""
original_wm_size=""
original_wifi=""
original_policy=""
original_font_scale=""
original_window_scale=""
original_transition_scale=""
original_animator_scale=""
android_overrides_started=0

cleanup() {
  local exit_code="$?"
  trap - EXIT INT TERM

  if [[ -n "$android_serial" ]]; then
    if [[ -n "$recording_host_pid" ]]; then
      local remote_pid="$($adb_bin -s "$android_serial" shell pidof screenrecord 2>/dev/null | tr -d '\r')"
      [[ -z "$remote_pid" ]] || "$adb_bin" -s "$android_serial" shell kill -2 "$remote_pid" >/dev/null 2>&1 || true
      wait "$recording_host_pid" >/dev/null 2>&1 || true
    fi

    if (( android_overrides_started )); then
      if [[ "$original_wm_size" == *"Override size:"* ]]; then
        local override="${original_wm_size##*Override size: }"
        "$adb_bin" -s "$android_serial" shell wm size "$override" >/dev/null 2>&1 || true
      else
        "$adb_bin" -s "$android_serial" shell wm size reset >/dev/null 2>&1 || true
      fi
      [[ -z "$original_wifi" || "$original_wifi" != "1" ]] \
        || "$adb_bin" -s "$android_serial" shell svc wifi enable >/dev/null 2>&1 || true
      "$adb_bin" -s "$android_serial" shell dumpsys battery reset >/dev/null 2>&1 || true
      if [[ -n "$original_policy" && "$original_policy" != "null" ]]; then
        "$adb_bin" -s "$android_serial" shell settings put global policy_control \
          "$original_policy" >/dev/null 2>&1 || true
      else
        "$adb_bin" -s "$android_serial" shell settings delete global policy_control \
          >/dev/null 2>&1 || true
      fi
      [[ -z "$original_font_scale" || "$original_font_scale" == "null" ]] \
        || "$adb_bin" -s "$android_serial" shell settings put system font_scale \
          "$original_font_scale" >/dev/null 2>&1 || true
      [[ -z "$original_window_scale" || "$original_window_scale" == "null" ]] \
        || "$adb_bin" -s "$android_serial" shell settings put global window_animation_scale \
          "$original_window_scale" >/dev/null 2>&1 || true
      [[ -z "$original_transition_scale" || "$original_transition_scale" == "null" ]] \
        || "$adb_bin" -s "$android_serial" shell settings put global transition_animation_scale \
          "$original_transition_scale" >/dev/null 2>&1 || true
      [[ -z "$original_animator_scale" || "$original_animator_scale" == "null" ]] \
        || "$adb_bin" -s "$android_serial" shell settings put global animator_duration_scale \
          "$original_animator_scale" >/dev/null 2>&1 || true
      "$adb_bin" -s "$android_serial" shell rm -f /sdcard/dekisugi-rehearsal-window.xml \
        >/dev/null 2>&1 || true
    fi

    if (( started_android )); then
      "$adb_bin" -s "$android_serial" emu kill >/dev/null 2>&1 || true
    fi
  fi

  if (( exit_code != 0 )); then
    print -u2 -- "Rehearsal capture failed. Raw evidence kept at: $raw_root"
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

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

android_serial="$(find_android_serial || true)"
if [[ -z "$android_serial" ]]; then
  print -- "Starting Android emulator $android_avd..."
  "$emulator_bin" -avd "$android_avd" -no-window -no-audio -no-boot-anim \
    -no-snapshot-save >"$raw_root/android-emulator.log" 2>&1 &
  started_android=1
  for _ in {1..120}; do
    android_serial="$(find_android_serial || true)"
    [[ -n "$android_serial" ]] && break
    sleep 1
  done
fi
[[ -n "$android_serial" ]] || { print -u2 -- "Android emulator did not appear"; exit 1; }

boot_completed=""
for _ in {1..120}; do
  boot_completed="$($adb_bin -s "$android_serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  [[ "$boot_completed" == "1" ]] && break
  sleep 1
done
[[ "$boot_completed" == "1" ]] || { print -u2 -- "Android emulator boot timed out"; exit 1; }

if (( build_app )); then
  print -- "Building the current Flutter rehearsal APK..."
  (cd "$app_dir" && flutter build apk --debug)
fi
[[ -f "$apk_path" ]] || { print -u2 -- "Missing APK: $apk_path"; exit 1; }
cp "$apk_path" "$raw_root/app-debug.apk"
apk_sha256="$(shasum -a 256 "$raw_root/app-debug.apk" | awk '{ print $1 }')"

original_wm_size="$($adb_bin -s "$android_serial" shell wm size | tr -d '\r')"
original_wifi="$($adb_bin -s "$android_serial" shell settings get global wifi_on | tr -d '\r')"
original_policy="$($adb_bin -s "$android_serial" shell settings get global policy_control | tr -d '\r')"
original_font_scale="$($adb_bin -s "$android_serial" shell settings get system font_scale | tr -d '\r')"
original_window_scale="$($adb_bin -s "$android_serial" shell settings get global window_animation_scale | tr -d '\r')"
original_transition_scale="$($adb_bin -s "$android_serial" shell settings get global transition_animation_scale | tr -d '\r')"
original_animator_scale="$($adb_bin -s "$android_serial" shell settings get global animator_duration_scale | tr -d '\r')"
android_overrides_started=1

"$adb_bin" -s "$android_serial" shell wm size 1080x1920 >/dev/null
"$adb_bin" -s "$android_serial" shell svc wifi disable >/dev/null
"$adb_bin" -s "$android_serial" shell dumpsys battery set level 100 >/dev/null
"$adb_bin" -s "$android_serial" shell dumpsys battery set ac 1 >/dev/null
"$adb_bin" -s "$android_serial" shell settings put global policy_control \
  'immersive.navigation=*' >/dev/null
"$adb_bin" -s "$android_serial" shell settings put system font_scale 1.0 >/dev/null
"$adb_bin" -s "$android_serial" shell settings put global window_animation_scale 1.0 >/dev/null
"$adb_bin" -s "$android_serial" shell settings put global transition_animation_scale 1.0 >/dev/null
"$adb_bin" -s "$android_serial" shell settings put global animator_duration_scale 1.0 >/dev/null
"$adb_bin" -s "$android_serial" install -r "$raw_root/app-debug.apk" >/dev/null

ui_xml="$raw_root/window.xml"

dump_ui() {
  "$adb_bin" -s "$android_serial" shell uiautomator dump --compressed \
    /sdcard/dekisugi-rehearsal-window.xml >/dev/null 2>&1 || true
  "$adb_bin" -s "$android_serial" exec-out cat \
    /sdcard/dekisugi-rehearsal-window.xml > "$ui_xml" 2>/dev/null || true
}

find_ui_coordinates() {
  local target="$1"
  local kind="${2:-any}"
  dump_ui
  python3 - "$ui_xml" "$target" "$kind" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

path, target, kind = sys.argv[1:]
try:
    root = ET.parse(path).getroot()
except (ET.ParseError, OSError):
    raise SystemExit(0)

candidates = []
for node in root.iter("node"):
    if node.attrib.get("enabled") != "true":
        continue
    class_name = node.attrib.get("class", "")
    if kind == "button" and not class_name.endswith("Button"):
        continue
    if kind == "edit" and not class_name.endswith("EditText"):
        continue
    haystack = "\n".join(
        node.attrib.get(name, "") for name in ("text", "content-desc", "hint")
    )
    if target not in haystack:
        continue
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.attrib.get("bounds", ""))
    if not match:
        continue
    left, top, right, bottom = map(int, match.groups())
    visible_left, visible_top = max(left, 0), max(top, 0)
    visible_right, visible_bottom = min(right, 1080), min(bottom, 1920)
    if visible_right <= visible_left or visible_bottom <= visible_top:
        continue
    area = (visible_right - visible_left) * (visible_bottom - visible_top)
    preferred = 0 if class_name.endswith(("Button", "EditText")) else 1
    center_x = (visible_left + visible_right) // 2
    if kind == "edit":
        # Flutter can merge a TextField with the explanatory widgets above it.
        # The merged accessibility rect then starts hundreds of pixels before
        # the actual editable surface. Its lower visible area remains inside
        # the TextField, so tap there instead of the misleading rect center.
        visible_height = visible_bottom - visible_top
        lower_inset = min(120, max(32, visible_height // 5))
        center_y = visible_bottom - lower_inset
    else:
        center_y = (visible_top + visible_bottom) // 2
    candidates.append((preferred, area, center_x, center_y))

if candidates:
    _, _, x, y = min(candidates)
    print(f"{x} {y}")
PY
}

wait_for_ui() {
  local target="$1"
  local kind="${2:-any}"
  local attempts="${3:-20}"
  local coordinates=""
  for (( attempt = 1; attempt <= attempts; attempt++ )); do
    coordinates="$(find_ui_coordinates "$target" "$kind")"
    [[ -n "$coordinates" ]] && return 0
    sleep 1
  done
  print -u2 -- "Timed out waiting for UI text: $target"
  return 1
}

tap_ui() {
  local target="$1"
  local kind="${2:-button}"
  local coordinates=""
  for _ in {1..12}; do
    coordinates="$(find_ui_coordinates "$target" "$kind")"
    [[ -n "$coordinates" ]] && break
    sleep .5
  done
  [[ -n "$coordinates" ]] || { print -u2 -- "Could not tap UI text: $target"; exit 1; }
  "$adb_bin" -s "$android_serial" shell input tap \
    "${coordinates%% *}" "${coordinates##* }" >/dev/null
  sleep .8
}

scroll_until_visible() {
  local target="$1"
  local kind="${2:-any}"
  local coordinates=""
  for _ in {1..14}; do
    coordinates="$(find_ui_coordinates "$target" "$kind")"
    [[ -n "$coordinates" ]] && { print -r -- "$coordinates"; return 0; }
    "$adb_bin" -s "$android_serial" shell input swipe 540 1536 540 384 320 >/dev/null
    sleep .6
  done
  print -u2 -- "Could not scroll to UI text: $target"
  return 1
}

scroll_to_and_tap() {
  local target="$1"
  local kind="${2:-button}"
  local coordinates="$(scroll_until_visible "$target" "$kind")"
  "$adb_bin" -s "$android_serial" shell input tap \
    "${coordinates%% *}" "${coordinates##* }" >/dev/null
  sleep .8
}

find_field_before_button_coordinates() {
  local target="$1"
  local button_target="$2"
  dump_ui
  python3 - "$ui_xml" "$target" "$button_target" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

path, target, button_target = sys.argv[1:]
try:
    root = ET.parse(path).getroot()
except (ET.ParseError, OSError):
    raise SystemExit(0)

def bounds(node):
    match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.attrib.get("bounds", ""))
    return tuple(map(int, match.groups())) if match else None

field = None
button = None
for node in root.iter("node"):
    class_name = node.attrib.get("class", "")
    haystack = "\n".join(node.attrib.get(name, "") for name in ("text", "content-desc", "hint"))
    if class_name.endswith("EditText") and node.attrib.get("enabled") == "true" and target in haystack:
        field = bounds(node)
    # The following primary button is intentionally disabled until text has
    # been entered, but its bounds are still the reliable layout anchor.
    if class_name.endswith("Button") and button_target in haystack:
        button = bounds(node)

if field and button:
    left, top, right, bottom = field
    _, button_top, _, _ = button
    # The TextField is 4 visible lines tall. Its center is consistently about
    # 350 framebuffer pixels above the following primary button at this capture
    # density. Clamp to the merged semantic rect in case text reflow shifts it.
    x = (max(left, 0) + min(right, 1080)) // 2
    y = max(max(top, 0) + 40, min(button_top - 350, min(bottom, 1920) - 40))
    print(f"{x} {y}")
PY
}

type_into_field() {
  local target="$1"
  local value="$2"
  local next_button="$3"
  local coordinates=""
  for _ in {1..14}; do
    coordinates="$(find_field_before_button_coordinates "$target" "$next_button")"
    [[ -n "$coordinates" ]] && break
    "$adb_bin" -s "$android_serial" shell input swipe 540 1536 540 384 320 >/dev/null
    sleep .6
  done
  [[ -n "$coordinates" ]] || {
    print -u2 -- "Could not locate editable surface before: $next_button"
    exit 1
  }
  local ime_shown=0
  # A scroll settling in the same frame can consume the first focus tap.
  # Retry the same real TextField target; never fall back to a fixed screen
  # coordinate or continue by pretending the input was accepted.
  local focus_attempt
  local poll_attempt
  for focus_attempt in {1..3}; do
    "$adb_bin" -s "$android_serial" shell input tap \
      "${coordinates%% *}" "${coordinates##* }" >/dev/null
    for poll_attempt in {1..8}; do
      if "$adb_bin" -s "$android_serial" shell dumpsys input_method \
        | grep -q 'mInputShown=true'; then
        ime_shown=1
        break
      fi
      sleep .3
    done
    (( ime_shown )) && break
    sleep .5
  done
  (( ime_shown )) || { print -u2 -- "Keyboard did not open for: $target"; exit 1; }
  local encoded="${value// /%s}"
  "$adb_bin" -s "$android_serial" shell input text "$encoded" >/dev/null
  sleep .7
  "$adb_bin" -s "$android_serial" shell input keyevent 4 >/dev/null
  sleep .8
  wait_for_ui "${value%% *}" any 8
}

fresh_launch() {
  "$adb_bin" -s "$android_serial" shell pm clear "$bundle_id" >/dev/null
  "$adb_bin" -s "$android_serial" shell am start -n "$bundle_id/.MainActivity" >/dev/null
  wait_for_ui "30秒おためしミッション" any 30
}

enter_local_only() {
  scroll_to_and_tap "通信しない端末内モードを使う" button
  wait_for_ui "DEVICE-ONLY STUDIO" any 20
}

begin_clip() {
  recording_name="$1"
  recording_remote_path="/sdcard/dekisugi-rehearsal-${recording_name}-$$.mp4"
  "$adb_bin" -s "$android_serial" shell screenrecord \
    --size 1080x1920 --bit-rate 8M --time-limit 60 \
    "$recording_remote_path" >"$raw_root/${recording_name}.screenrecord.log" 2>&1 &
  recording_host_pid="$!"
  sleep 1
}

end_clip() {
  sleep .6
  local remote_pid="$($adb_bin -s "$android_serial" shell pidof screenrecord 2>/dev/null | tr -d '\r')"
  [[ -z "$remote_pid" ]] || "$adb_bin" -s "$android_serial" shell kill -2 "$remote_pid" >/dev/null
  wait "$recording_host_pid" >/dev/null 2>&1 || true
  recording_host_pid=""
  "$adb_bin" -s "$android_serial" pull "$recording_remote_path" \
    "$raw_root/${recording_name}.mp4" >/dev/null
  "$adb_bin" -s "$android_serial" shell rm -f "$recording_remote_path" >/dev/null
  recording_remote_path=""
  local duration="$($ffprobe_bin -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$raw_root/${recording_name}.mp4")"
  # Android's encoder can emit a sub-second elementary timeline for a longer
  # static hold because no new display frame is produced. The edit stage pads
  # that verified real frame to the scheduled duration.
  if [[ "$duration" == "N/A" ]]; then
    local frames="$($ffprobe_bin -v error -select_streams v:0 \
      -show_entries stream=nb_frames -of default=noprint_wrappers=1:nokey=1 \
      "$raw_root/${recording_name}.mp4")"
    [[ "$frames" == <-> && "$frames" -ge 1 ]] || {
      print -u2 -- "Recorded static clip has no decodable frame: $recording_name"
      exit 1
    }
    duration="static-${frames}-frame"
  else
    awk -v duration="$duration" 'BEGIN { exit !(duration > 0.2) }' || {
      print -u2 -- "Recorded clip is too short: $recording_name ($duration s)"
      exit 1
    }
  fi
  print -- "Recorded $recording_name (${duration}s)"
}

print -- "Recording deterministic on-device rehearsal on $android_serial..."

# C01 — tutorial misconception correction to deterministic clear.
fresh_launch
tap_ui "同時に着く" button
wait_for_ui "デキすぎ君の思い込み" any 15
begin_clip "01-tutorial-misconception"
tap_ui "違う。空気の抵抗を無視すれば" button
wait_for_ui "TUTORIAL CLEAR" any 15
sleep 2
end_clip

# C02 — no dashboard: the fresh first mission is the landing evidence.
fresh_launch
begin_clip "02-first-local-mission"
sleep 6
end_clip

# C03 — enter the real structurally local-only route from the consent screen.
scroll_until_visible "通信しない端末内モードを使う" button >/dev/null
begin_clip "03-device-only-assurance"
tap_ui "通信しない端末内モードを使う" button
wait_for_ui "DEVICE-ONLY STUDIO" any 15
sleep 3
"$adb_bin" -s "$android_serial" shell input swipe 540 1500 540 900 500 >/dev/null
sleep 2
end_clip

# C04 — the real queued local mission, one focused source, and a tactic.
scroll_until_visible "この1件をはじめる" button >/dev/null
begin_clip "04-source-and-tactic"
tap_ui "この1件をはじめる" button
wait_for_ui "作戦を準備する" any 15
scroll_until_visible "しくみ・理由から" button >/dev/null
tap_ui "しくみ・理由から" button
tap_ui "この作戦で挑む" button
wait_for_ui "端末内練習、4段階のうち1段階目" any 15
sleep 1
end_clip

# C05 — three actual text-entry stages; inputs are local screen state only.
begin_clip "05-offline-recall-reason-transfer"
type_into_field "自分の説明" "Gravity pulls every object downward" "説明を書いた"
scroll_to_and_tap "説明を書いた" button
wait_for_ui "4段階のうち2段階目" any 10
type_into_field "足す条件・理由" "This holds when air resistance is negligible" "条件・理由を足した"
scroll_to_and_tap "条件・理由を足した" button
wait_for_ui "4段階のうち3段階目" any 10
type_into_field "予想と理由" "The crumpled sheet falls first because it meets less drag" "チェックポイントへ"
scroll_to_and_tap "チェックポイントへ" button
wait_for_ui "固定の思い込みを見破る" any 10
sleep 1
end_clip

# C06 — an incorrect reason produces a cataloged hint and cannot clear.
begin_clip "06-checkpoint-hint"
scroll_to_and_tap "重い球が先に着く" button
scroll_to_and_tap "この直し方で決める" button
wait_for_ui "重い球は強く引かれますが" any 15
sleep 3
end_clip

# C07 — condition-based correction reaches the deterministic completion.
begin_clip "07-local-checkpoint-clear"
scroll_to_and_tap "2つは同時に着く" button
scroll_to_and_tap "この直し方で決める" button
wait_for_ui "ローカルチェックポイントをクリア" any 15
sleep 5
end_clip

# C08 — minimal local marker, private self-check, then the rotated Home.
begin_clip "08-source-comparison"
wait_for_ui "教材と概念、完了回数、最終完了日時だけ" any 15
sleep 2
scroll_until_visible "練習を完了" button >/dev/null
tap_ui "練習を完了" button
wait_for_ui "次の端末内ミッション" any 15
sleep 2
end_clip

# Keep the completed local-only state and change the real Android text setting.
# This makes the one-record rotation visible instead of clearing it for a demo.
"$adb_bin" -s "$android_serial" shell settings put system font_scale 2.0 >/dev/null
"$adb_bin" -s "$android_serial" shell settings put global window_animation_scale 0 >/dev/null
"$adb_bin" -s "$android_serial" shell settings put global transition_animation_scale 0 >/dev/null
"$adb_bin" -s "$android_serial" shell settings put global animator_duration_scale 0 >/dev/null
sleep 2
"$adb_bin" -s "$android_serial" shell am start \
  -a android.settings.TEXT_READING_SETTINGS >/dev/null
sleep 2

# C09 — real system 200% text page, followed by the app reflow at that setting.
begin_clip "09-accessibility-200-percent"
sleep 4
"$adb_bin" -s "$android_serial" shell am force-stop com.android.settings >/dev/null
"$adb_bin" -s "$android_serial" shell am start -n "$bundle_id/.MainActivity" >/dev/null
wait_for_ui "DEVICE-ONLY STUDIO" any 15
sleep 6
end_clip

# C10 — hold on the actual local-only boundary for the rehearsal disclaimer.
begin_clip "10-rehearsal-boundary"
sleep 3
"$adb_bin" -s "$android_serial" shell input swipe 540 1450 540 850 500 >/dev/null
sleep 3
end_clip

clip_names=(
  01-tutorial-misconception
  02-first-local-mission
  03-device-only-assurance
  04-source-and-tactic
  05-offline-recall-reason-transfer
  06-checkpoint-hint
  07-local-checkpoint-clear
  08-source-comparison
  09-accessibility-200-percent
  10-rehearsal-boundary
)
clip_durations=(6 8 10 12 18 10 13 12 13 8)

concat_list="$raw_root/concat.txt"
: > "$concat_list"
for index in {1..10}; do
  name="${clip_names[$index]}"
  duration="${clip_durations[$index]}"
  normalized="$raw_root/normalized/${name}.mp4"
  source_duration="$($ffprobe_bin -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$raw_root/${name}.mp4")"
  if awk -v source_duration="$source_duration" \
    'BEGIN { exit !(source_duration != "N/A" && source_duration > 0.001) }'; then
    "$ffmpeg_bin" -hide_banner -loglevel error -y \
      -i "$raw_root/${name}.mp4" \
      -vf "scale=1080:1920:flags=lanczos,setsar=1,fps=30,tpad=stop_mode=clone:stop_duration=60,setpts=PTS-STARTPTS" \
      -t "$duration" -an -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
      -movflags +faststart "$normalized"
  else
    # Android may encode an unchanged screen as one decodable frame with no
    # duration. Preserve the real recorded state for its scheduled natural
    # hold; do not let concat silently drop the clip or invent another frame.
    still_frame="$raw_root/normalized/${name}.source.png"
    "$ffmpeg_bin" -hide_banner -loglevel error -y \
      -i "$raw_root/${name}.mp4" \
      -vf "scale=1080:1920:flags=lanczos,setsar=1" \
      -frames:v 1 "$still_frame"
    "$ffmpeg_bin" -hide_banner -loglevel error -y \
      -loop 1 -framerate 30 -i "$still_frame" \
      -t "$duration" -an -c:v libx264 -preset medium -crf 18 -pix_fmt yuv420p \
      -movflags +faststart "$normalized"
  fi
  print -r -- "file '$normalized'" >> "$concat_list"
done

base_video="$raw_root/rehearsal-base.mp4"
"$ffmpeg_bin" -hide_banner -loglevel error -y \
  -f concat -safe 0 -i "$concat_list" -c copy -an "$base_video"

candidate="$output_dir/.dekisugi-on-device-rehearsal.candidate.$$.mp4"
subtitle_filter="subtitles=${caption_path}:force_style='FontName=Helvetica,FontSize=7,PrimaryColour=&H00FFFFFF,BackColour=&H80000000,BorderStyle=3,Outline=1,Shadow=0,Alignment=2,MarginV=32'"
"$ffmpeg_bin" -hide_banner -loglevel error -y \
  -i "$base_video" -vf "$subtitle_filter" -r 30 -an \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -movflags +faststart \
  -metadata title="Dekisugi on-device rehearsal — NOT PUBLIC SUBMISSION" \
  -metadata artist="Haruka-Kaya" \
  -metadata comment="REHEARSAL ONLY; deterministic on-device route; debug APK SHA-256 $apk_sha256; no Store release, revenue, live-AI approval, or school deployment claim" \
  "$candidate"

print -- "Verifying rehearsal export..."
"$repo_root/tools/verify-shipaton-demo-rehearsal.sh" "$candidate"
mv -f "$candidate" "$output_path"
print -- "Final rehearsal: $output_path"
print -- "Raw evidence (outside repo): $raw_root"
print -- "Captured debug APK SHA-256: $apk_sha256"
