#!/usr/bin/env bash
# Build Minizork for Neo6502, drive the instrumented-free emulator, and assert
# that the rendered console contains the previously corrupted leaflet text.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/tools"

STORY="${NEO_SMOKE_STORY:-examples/minizork.z3}"
OZMOO_HOME="${OZMOO_HOME:-/tmp/ozmoo-home}"
DEFAULT_FIRMWARE_ROOT="$(cd -- "$ROOT_DIR/.." && pwd)/neo6502-firmware"
FIRMWARE_ROOT="${NEO_FIRMWARE_ROOT:-$DEFAULT_FIRMWARE_ROOT}"
EMULATOR="$FIRMWARE_ROOT/emulator/neo"
FONT_HEADER="$FIRMWARE_ROOT/firmware/common/include/interface/font_5x7.h"
WORKDIR="${NEO_SMOKE_WORKDIR:-/tmp/opencode/neo-smoke}"

SKIP_BUILD="${NEO_SMOKE_SKIP_BUILD:-0}"
BOOT_DELAY="${NEO_SMOKE_BOOT_DELAY:-4}"
COMMAND_DELAY="${NEO_SMOKE_COMMAND_DELAY:-5}"
FINAL_DELAY="${NEO_SMOKE_FINAL_DELAY:-3}"
WINDOW_TIMEOUT="${NEO_SMOKE_WINDOW_TIMEOUT:-10}"

mkdir -p "$WORKDIR"
LOG="$WORKDIR/emulator.log"
SCREENSHOT="$WORKDIR/screen.png"
DECODED="$WORKDIR/decoded.txt"
INVERTED_REPORT="$WORKDIR/inverted.txt"

EMU_PID=""
WINDOW_ID=""

cleanup() {
    if [[ -n "$EMU_PID" ]] && kill -0 "$EMU_PID" 2>/dev/null; then
        kill "$EMU_PID" 2>/dev/null || true
        wait "$EMU_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "ERROR: required command not found: $1" >&2
        exit 1
    }
}

require_file() {
    [[ -f "$1" ]] || {
        echo "ERROR: required file not found: $1" >&2
        exit 1
    }
}

require_command ruby
require_command python3
require_command xdotool
require_command import
require_file "$EMULATOR"
require_file "$FONT_HEADER"
require_file "$TOOLS_DIR/decode_neo_console.py"

python3 -c 'import PIL' >/dev/null 2>&1 || {
    echo "ERROR: Pillow is required by tools/decode_neo_console.py" >&2
    exit 1
}

cd "$ROOT_DIR"

if [[ "$SKIP_BUILD" != "1" ]]; then
    echo "Building $STORY for Neo6502..."
    BUILD_ARGS=(-t:neo6502 -v "$STORY")
    if [[ -n "${NEO_SMOKE_FG:-}" ]]; then
        BUILD_ARGS+=("-neo-fg:$NEO_SMOKE_FG")
    fi
    if [[ -n "${NEO_SMOKE_BG:-}" ]]; then
        BUILD_ARGS+=("-neo-bg:$NEO_SMOKE_BG")
    fi
    env OZMOO_HOME="$OZMOO_HOME" ruby make.rb "${BUILD_ARGS[@]}"
fi

GAME_BASE="$(basename "${STORY%.*}")"
GAME_8_3="$(printf '%s' "$GAME_BASE" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9' | cut -c1-8)"
[[ -n "$GAME_8_3" ]] || GAME_8_3="STORY"
RELEASE_DIR="$ROOT_DIR/dist/$GAME_BASE"
require_file "$RELEASE_DIR/$GAME_8_3.NEO"
require_file "$RELEASE_DIR/$GAME_8_3.STORY"
require_file "$RELEASE_DIR/$GAME_8_3.CFG"

rm -f "$LOG" "$SCREENSHOT" "$DECODED" "$INVERTED_REPORT"

echo "Starting emulator with the packaged .NEO..."
"$EMULATOR" \
    cold \
    "$RELEASE_DIR/$GAME_8_3.NEO" \
    "path:$RELEASE_DIR" \
    > "$LOG" 2>&1 &
EMU_PID=$!

deadline=$((SECONDS + WINDOW_TIMEOUT))
while [[ -z "$WINDOW_ID" ]]; do
    WINDOW_ID="$(xdotool search --pid "$EMU_PID" 2>/dev/null | head -n 1 || true)"
    if [[ -z "$WINDOW_ID" ]]; then
        if ((SECONDS >= deadline)); then
            echo "ERROR: emulator window did not appear within ${WINDOW_TIMEOUT}s" >&2
            tail -40 "$LOG" >&2 || true
            exit 1
        fi
        sleep 0.2
    fi
done

sleep "$BOOT_DELAY"

send_line() {
    xdotool windowactivate --sync "$WINDOW_ID"
    sleep 0.2
    xdotool type --delay 60 -- "$1"
    xdotool key Return
}

echo "Injecting smoke-test commands..."
send_line "open mailbox"
sleep "$COMMAND_DELAY"
send_line "read leaflet"
sleep "$FINAL_DELAY"

echo "Capturing console..."
import -window "$WINDOW_ID" "$SCREENSHOT"
DECODE_ARGS=(--report-inverted)
if [[ -n "${NEO_SMOKE_FG_RGB:-}" ]]; then
    DECODE_ARGS+=(--fg-rgb "$NEO_SMOKE_FG_RGB")
fi
if [[ -n "${NEO_SMOKE_BG_RGB:-}" ]]; then
    DECODE_ARGS+=(--bg-rgb "$NEO_SMOKE_BG_RGB")
fi
python3 "$TOOLS_DIR/decode_neo_console.py" "${DECODE_ARGS[@]}" \
    "$SCREENSHOT" "$FONT_HEADER" > "$DECODED" 2> "$INVERTED_REPORT"

failures=0

expect_text() {
    if ! grep -Fq "$1" "$DECODED"; then
        echo "FAIL: expected text not found: $1" >&2
        failures=$((failures + 1))
    fi
}

expect_regex() {
    if ! grep -Eq "$1" "$DECODED"; then
        echo "FAIL: expected pattern not found: $1" >&2
        failures=$((failures + 1))
    fi
}

expect_text "Opening the small mailbox reveals a leaflet."
# If resident VMEM reaches the C64-compatible I/O window, init_screen_colours
# rewrites the story bytes at $d020/$d021 and this phrase decodes as
# "puzzlesthe cof escriptions".
expect_text "puzzles, and descriptions"
expect_text "the larger, disk-based version of Zork I."
expect_text '"WELCOME TO ZORK, a game of adventure'
expect_text ">read leaflet"
# The score line must fit on row 0; a reserve that is one column too small
# makes the final move count wrap into the lower window.
expect_regex '^00: West of House +SC:[0-9]+ MV:[0-9]+ *$'
expect_regex '^29: >'

# Only the top status line is inverse video on Neo6502.
if ! grep -Fq 'INVERTED_ROWS=0' "$INVERTED_REPORT"; then
    echo "FAIL: expected only row 0 to use inverse video colours" >&2
    cat "$INVERTED_REPORT" >&2
    failures=$((failures + 1))
fi

if grep -Fq "BH!CJ" "$DECODED"; then
    echo "FAIL: known corrupted leaflet text is present" >&2
    failures=$((failures + 1))
fi

if ((failures > 0)); then
    echo "--- decoded console ---" >&2
    cat "$DECODED" >&2
    echo "--- emulator log tail ---" >&2
    tail -40 "$LOG" >&2 || true
    exit 1
fi

echo "PASS: Neo6502 smoke test"
echo "  screenshot: $SCREENSHOT"
echo "  decoded:    $DECODED"
echo "  log:        $LOG"
