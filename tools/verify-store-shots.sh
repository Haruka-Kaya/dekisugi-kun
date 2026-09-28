#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir:h}"
shots_root="${1:-$repo_root/docs/store-shots-2026}"
inspector_source="$repo_root/tools/inspect-store-shot.swift"
temp_base="${TMPDIR:-/tmp}"
work_dir="$(mktemp -d "$temp_base/dekisugi-store-shot-verify.XXXXXX")"
inspector_bin="$work_dir/inspect-store-shot"

cleanup() {
  local exit_code="$?"
  trap - EXIT INT TERM
  if [[ -n "$work_dir" && "$work_dir" == "$temp_base"/dekisugi-store-shot-verify.* ]]; then
    rm -rf -- "$work_dir"
  fi
  exit "$exit_code"
}
trap cleanup EXIT INT TERM

[[ -f "$inspector_source" ]] || { print -u2 -- "ERROR: missing $inspector_source"; exit 1; }
xcrun swiftc "$inspector_source" -o "$inspector_bin"

fail() {
  print -u2 -- "ERROR: $*"
  exit 1
}

property() {
  local file="$1"
  local name="$2"
  /usr/bin/sips -g "$name" "$file" 2>/dev/null \
    | /usr/bin/awk -F': ' -v key="$name" '$1 ~ "^[[:space:]]*" key "$" { print $2 }'
}

assert_equal() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  [[ "$actual" == "$expected" ]] \
    || fail "$label: expected '$expected', got '$actual'"
}

verify_rgb_image() {
  local file="$1"
  local expected_width="$2"
  local expected_height="$3"
  local expected_format="$4"

  [[ -f "$file" ]] || fail "missing image: $file"

  local width="$(property "$file" pixelWidth)"
  local height="$(property "$file" pixelHeight)"
  local alpha="$(property "$file" hasAlpha)"
  local samples="$(property "$file" samplesPerPixel)"
  local bits="$(property "$file" bitsPerSample)"
  local space="$(property "$file" space)"
  local format="$(property "$file" format)"

  assert_equal "$width" "$expected_width" "$file width"
  assert_equal "$height" "$expected_height" "$file height"
  assert_equal "$alpha" "no" "$file alpha"
  assert_equal "$samples" "3" "$file samples per pixel"
  assert_equal "$bits" "8" "$file bits per sample"
  assert_equal "$space" "RGB" "$file color space"
  assert_equal "$format" "$expected_format" "$file format"

  print -- "PASS  ${file#$repo_root/}  ${width}x${height}  ${format}  RGB  ${bits}-bit x ${samples}  alpha=${alpha}"
}

iphone_shot="$shots_root/app-store/iphone-6.9/01-first-mission-predict.png"
ipad_shot="$shots_root/app-store/ipad-13/01-first-mission-predict.png"
shipaton_shot="$shots_root/shipaton/iphone-1179x2556/01-first-mission-predict.png"

verify_rgb_image "$iphone_shot" 1320 2868 png
verify_rgb_image "$ipad_shot" 2064 2752 png
verify_rgb_image "$shipaton_shot" 1179 2556 png

for initial_shot in "$iphone_shot" "$ipad_shot" "$shipaton_shot"; do
  "$inspector_bin" "$initial_shot" \
    --require "30秒おためしミッション" \
    --forbid "Ready for Apple Intelligence" \
    --forbid "Time to experience the new personal intelligence system" \
    --forbid "まだ始まっていません" \
    --forbid "もう一度見るところ" \
    --corner-rgb F6F2E9
done

play_shots=(
  "$shots_root/google-play/phone/01-first-mission-predict.jpg"
  "$shots_root/google-play/phone/02-first-mission-challenge.jpg"
  "$shots_root/google-play/phone/03-first-mission-clear.jpg"
  "$shots_root/google-play/phone/04-device-only-studio.jpg"
)

for shot in "${play_shots[@]}"; do
  verify_rgb_image "$shot" 1080 1920 jpeg

  width="$(property "$shot" pixelWidth)"
  height="$(property "$shot" pixelHeight)"
  short_side="$width"
  long_side="$height"
  if (( width > height )); then
    short_side="$height"
    long_side="$width"
  fi
  (( short_side >= 320 )) || fail "$shot: Google Play minimum dimension is 320px"
  (( long_side <= 3840 )) || fail "$shot: Google Play maximum dimension is 3840px"
  (( long_side <= short_side * 2 )) \
    || fail "$shot: Google Play long side exceeds twice the short side"
  (( width * 16 == height * 9 )) || fail "$shot: expected a 9:16 portrait image"
done

"$inspector_bin" "${play_shots[1]}" \
  --require "30秒おためしミッション" \
  --forbid "Ready for Apple Intelligence" \
  --forbid "まだ始まっていません" \
  --forbid "もう一度見るところ"
"$inspector_bin" "${play_shots[2]}" \
  --require "デキすぎ君の思い込み" \
  --forbid "Ready for Apple Intelligence" \
  --forbid "まだ始まっていません" \
  --forbid "もう一度見るところ"
"$inspector_bin" "${play_shots[3]}" \
  --require "TUTORIAL CLEAR" \
  --forbid "Ready for Apple Intelligence" \
  --forbid "まだ始まっていません" \
  --forbid "もう一度見るところ"
"$inspector_bin" "${play_shots[4]}" \
  --require "答えを送らず" \
  --require "教材と概念、完了回数" \
  --forbid "Ready for Apple Intelligence" \
  --forbid "送らず、残さず" \
  --forbid "まだ始まっていません" \
  --forbid "もう一度見るところ"

print -- "PASS  all generated samples satisfy the encoded 2026 target constraints"

for generated in \
  "$iphone_shot" \
  "$ipad_shot" \
  "$shipaton_shot" \
  "${play_shots[@]}"; do
  for legacy in "$repo_root"/docs/shots/*.png; do
    cmp -s "$generated" "$legacy" \
      && fail "$generated is byte-identical to legacy UI asset $legacy"
  done
done

print -- "PASS  no generated sample is a legacy docs/shots image"
