#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
video_path="${1:-$repo_root/docs/shipaton-demo-2026/dekisugi-on-device-rehearsal.mp4}"
caption_path="$repo_root/docs/shipaton-demo-captions.en.srt"
inspector_source="$repo_root/tools/inspect-store-shot.swift"
ffmpeg_bin="${FFMPEG_BIN:-/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg}"
ffprobe_bin="${FFPROBE_BIN:-/opt/homebrew/opt/ffmpeg-full/bin/ffprobe}"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/dekisugi-shipaton-video-verify.XXXXXX")"
inspector_bin="$work_dir/inspect-store-shot"

cleanup() {
  local exit_code="$?"
  trap - EXIT INT TERM
  if [[ -n "$work_dir" && "$work_dir" == "${TMPDIR:-/tmp}"/dekisugi-shipaton-video-verify.* ]]; then
    rm -rf -- "$work_dir"
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

fail() {
  print -u2 -- "ERROR: $*"
  exit 1
}

[[ -f "$video_path" ]] || fail "missing rehearsal video: $video_path"
[[ -f "$caption_path" ]] || fail "missing caption source: $caption_path"
[[ -f "$inspector_source" ]] || fail "missing image inspector: $inspector_source"
[[ -x "$ffmpeg_bin" ]] || fail "ffmpeg-full not found: $ffmpeg_bin"
[[ -x "$ffprobe_bin" ]] || fail "ffprobe not found: $ffprobe_bin"

duration="$($ffprobe_bin -v error -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 "$video_path")"
awk -v duration="$duration" 'BEGIN { exit !(duration >= 105 && duration <= 115) }' \
  || fail "duration must be 1:45–1:55, got ${duration}s"

video_stream="$($ffprobe_bin -v error -select_streams v:0 \
  -show_entries stream=codec_name,width,height,pix_fmt,r_frame_rate,avg_frame_rate \
  -of default=noprint_wrappers=1 "$video_path")"
[[ "$video_stream" == *"codec_name=h264"* ]] || fail "video codec is not H.264"
[[ "$video_stream" == *"width=1080"* ]] || fail "video width is not 1080"
[[ "$video_stream" == *"height=1920"* ]] || fail "video height is not 1920"
[[ "$video_stream" == *"pix_fmt=yuv420p"* ]] || fail "video pixel format is not yuv420p"
[[ "$video_stream" == *"r_frame_rate=30/1"* ]] || fail "nominal frame rate is not 30fps"
[[ "$video_stream" == *"avg_frame_rate=30/1"* ]] || fail "average frame rate is not constant 30fps"

audio_streams="$($ffprobe_bin -v error -select_streams a \
  -show_entries stream=index -of csv=p=0 "$video_path" | wc -l | tr -d ' ')"
[[ "$audio_streams" == "0" ]] || fail "rehearsal must be silent; found $audio_streams audio stream(s)"
subtitle_streams="$($ffprobe_bin -v error -select_streams s \
  -show_entries stream=index -of csv=p=0 "$video_path" | wc -l | tr -d ' ')"
[[ "$subtitle_streams" == "0" ]] \
  || fail "captions must be burned in, not stored as a selectable subtitle stream"

title="$($ffprobe_bin -v error -show_entries format_tags=title \
  -of default=noprint_wrappers=1:nokey=1 "$video_path")"
comment="$($ffprobe_bin -v error -show_entries format_tags=comment \
  -of default=noprint_wrappers=1:nokey=1 "$video_path")"
[[ "$title" == *"NOT PUBLIC SUBMISSION"* ]] || fail "title lacks rehearsal-only marker"
[[ "$comment" == *"REHEARSAL ONLY"* ]] || fail "comment lacks rehearsal-only marker"
[[ "$comment" == *"no Store release"* ]] || fail "comment lacks unverified-claim boundary"

python3 - "$caption_path" <<'PY'
import re
import sys

text = open(sys.argv[1], encoding="utf-8").read()
times = re.findall(r"(\d{2}):(\d{2}):(\d{2}),(\d{3}) --> (\d{2}):(\d{2}):(\d{2}),(\d{3})", text)
if len(times) != 10:
    raise SystemExit(f"ERROR: expected 10 caption intervals, got {len(times)}")
last = times[-1][4:]
milliseconds = (((int(last[0]) * 60 + int(last[1])) * 60 + int(last[2])) * 1000 + int(last[3]))
if milliseconds != 110_000:
    raise SystemExit(f"ERROR: caption source must end at 110000ms, got {milliseconds}ms")
required = [
    "No account or network is required",
    "Free-response text is neither sent nor saved",
    "Only unit, concept, count, and time stay on-device",
    "A wrong choice returns a science hint",
    "System-level 200% text remains usable",
    "Rehearsal only: no Store release",
]
for phrase in required:
    if phrase not in text:
        raise SystemExit(f"ERROR: required truthful caption missing: {phrase}")
for forbidden in (
    "Nothing is uploaded",
    "nothing is saved",
    "no data is saved",
    "RevenueCat Plus changes only",
    "now available on the App Store",
    "deployed in schools",
    "live AI is approved",
):
    if forbidden.lower() in text.lower():
        raise SystemExit(f"ERROR: unverified public claim in captions: {forbidden}")
PY

xcrun swiftc "$inspector_source" -o "$inspector_bin"

extract_and_check() {
  local seconds="$1"
  local filename="$2"
  shift 2
  "$ffmpeg_bin" -hide_banner -loglevel error -y -ss "$seconds" \
    -i "$video_path" -frames:v 1 "$work_dir/$filename.png"
  "$inspector_bin" "$work_dir/$filename.png" "$@"
}

# English phrases exist only in the SRT, so OCR recognition proves that the
# captions are burned into pixels. Japanese markers additionally prove that
# the underlying frames came from the current deterministic UI.
extract_and_check 3 hook \
  --require "Do not pick" \
  --require "an answer"
extract_and_check 21 device-only \
  --require "text is neither sent nor saved" \
  --require "DEVICE-ONLY STUDIO" \
  --require "答えを送らず" \
  --forbid "送らず、残さず"
extract_and_check 60 checkpoint-hint \
  --require "wrong choice returns a science hint"
extract_and_check 81 local-record \
  --require "unit, concept, count, and time"
extract_and_check 95 accessibility \
  --require "System-level 200% text"
extract_and_check 106 boundary \
  --require "Rehearsal only" \
  --forbid "RevenueCat Plus changes only"

size_bytes="$(stat -f '%z' "$video_path")"
sha256="$(shasum -a 256 "$video_path" | awk '{ print $1 }')"
print -- "PASS  ${video_path#$repo_root/}"
print -- "PASS  duration=${duration}s  1080x1920  H.264  yuv420p  CFR=30fps"
print -- "PASS  audio=none  subtitle_stream=none  burned-caption OCR=6/6"
print -- "PASS  rehearsal metadata and unverified-claim boundaries"
print -- "PASS  bytes=$size_bytes  sha256=$sha256"
