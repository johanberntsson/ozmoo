#!/usr/bin/env bash
# Build Minizork for Neo6502, drive the emulator through SAVE/RESTORE, and
# assert that the native save files are used without CBM device prompts.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/tools"

STORY="${NEO_SAVE_RESTORE_STORY:-examples/minizork.z3}"
OZMOO_HOME="${OZMOO_HOME:-/tmp/ozmoo-home}"
DEFAULT_FIRMWARE_ROOT="$(cd -- "$ROOT_DIR/.." && pwd)/neo6502-firmware"
FIRMWARE_ROOT="${NEO_FIRMWARE_ROOT:-$DEFAULT_FIRMWARE_ROOT}"
EMULATOR="$FIRMWARE_ROOT/emulator/neo"
FONT_HEADER="$FIRMWARE_ROOT/firmware/common/include/interface/font_5x7.h"
WORKDIR="${NEO_SAVE_RESTORE_WORKDIR:-/tmp/opencode/neo-save-restore}"

SKIP_BUILD="${NEO_SAVE_RESTORE_SKIP_BUILD:-0}"
BOOT_DELAY="${NEO_SAVE_RESTORE_BOOT_DELAY:-4}"
COMMAND_DELAY="${NEO_SAVE_RESTORE_COMMAND_DELAY:-5}"
INPUT_DELAY="${NEO_SAVE_RESTORE_INPUT_DELAY:-2}"
FINAL_DELAY="${NEO_SAVE_RESTORE_FINAL_DELAY:-3}"
WINDOW_TIMEOUT="${NEO_SAVE_RESTORE_WINDOW_TIMEOUT:-10}"

mkdir -p "$WORKDIR"
LOG="$WORKDIR/emulator.log"

EMU_PID=""
WINDOW_ID=""
LAST_DECODED=""
failures=0

cleanup() {
    if [[ -n "$EMU_PID" ]] && kill -0 "$EMU_PID" 2>/dev/null; then
        kill "$EMU_PID" 2>/dev/null || true
        wait "$EMU_PID" 2>/dev/null || true
    fi
    EMU_PID=""
    WINDOW_ID=""
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
    env OZMOO_HOME="$OZMOO_HOME" ruby make.rb -t:neo6502 -P "$STORY"
fi

STORY_LOAD="$(sed -n 's/^[[:space:]]*story_start[[:space:]]*=[[:space:]]*$\([0-9A-Fa-f][0-9A-Fa-f]*\).*/\1/p' temp/acme_labels.txt | head -n 1)"
[[ -n "$STORY_LOAD" ]] || {
    echo "ERROR: could not find story_start in temp/acme_labels.txt" >&2
    exit 1
}

echo "Preparing raw emulator load files..."
tail -c +3 temp/ozmoo > temp/ozmoo-neo-main.bin
cp temp/compmem.tmp temp/ozmoo-neo-story.bin

echo "Preparing isolated Neo storage..."
GAME_BASE="$(basename "${STORY%.*}")"
GAME_8_3="$(printf '%s' "$GAME_BASE" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9' | cut -c1-8)"
[[ -n "$GAME_8_3" ]] || GAME_8_3="STORY"
RELEASE_DIR="$ROOT_DIR/dist/$GAME_BASE"
require_file "$RELEASE_DIR/$GAME_8_3.STORY"
require_file "$RELEASE_DIR/$GAME_8_3.CFG"

rm -rf "$WORKDIR"
mkdir -p "$WORKDIR/storage"
cp "$RELEASE_DIR/$GAME_8_3.STORY" "$WORKDIR/storage/"
cp "$RELEASE_DIR/$GAME_8_3.CFG" "$WORKDIR/storage/"
SAVE_FILE="$WORKDIR/storage/$GAME_8_3.S00"

wait_for_window() {
    local deadline=$((SECONDS + WINDOW_TIMEOUT))
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
}

start_emulator() {
    echo "Starting emulator..."
    : > "$LOG"
    "$EMULATOR" \
        cold \
        "$ROOT_DIR/temp/ozmoo-neo-main.bin@1000" \
        "$ROOT_DIR/temp/ozmoo-neo-story.bin@$STORY_LOAD" \
        "path:$WORKDIR/storage" \
        run@1000 > "$LOG" 2>&1 &
    EMU_PID=$!
    wait_for_window
    sleep "$BOOT_DELAY"
}

stop_emulator() {
    if [[ -n "$EMU_PID" ]] && kill -0 "$EMU_PID" 2>/dev/null; then
        kill "$EMU_PID" 2>/dev/null || true
        wait "$EMU_PID" 2>/dev/null || true
    fi
    EMU_PID=""
    WINDOW_ID=""
}

send_line() {
    xdotool windowactivate --sync "$WINDOW_ID"
    sleep 0.2
    xdotool type --delay 60 -- "$1"
    xdotool key Return
}

capture_console() {
    local screenshot="$1"
    local decoded="$2"
    import -window "$WINDOW_ID" "$screenshot"
    local decode_args=()
    if [[ -n "${NEO_SMOKE_FG_RGB:-}" ]]; then
        decode_args+=(--fg-rgb "$NEO_SMOKE_FG_RGB")
    fi
    if [[ -n "${NEO_SMOKE_BG_RGB:-}" ]]; then
        decode_args+=(--bg-rgb "$NEO_SMOKE_BG_RGB")
    fi
    python3 "$TOOLS_DIR/decode_neo_console.py" "${decode_args[@]}" "$screenshot" "$FONT_HEADER" > "$decoded"
    LAST_DECODED="$decoded"
}

expect_text() {
    local text="$1"
    local decoded="${2:-$LAST_DECODED}"
    if ! grep -Fq -- "$text" "$decoded"; then
        echo "FAIL: expected text not found: $text" >&2
        failures=$((failures + 1))
    fi
}

reject_text() {
    local text="$1"
    local decoded="${2:-$LAST_DECODED}"
    if grep -Fq -- "$text" "$decoded"; then
        echo "FAIL: unexpected text found: $text" >&2
        failures=$((failures + 1))
    fi
}

start_emulator

echo "Establishing initial location..."
send_line "look"
sleep "$COMMAND_DELAY"

echo "Saving to slot 0..."
send_line "save"
sleep "$INPUT_DELAY"
send_line "0"
sleep "$INPUT_DELAY"
send_line "test save"
sleep "$FINAL_DELAY"

SAVE_DECODED="$WORKDIR/save-decoded.txt"
capture_console "$WORKDIR/save-screen.png" "$SAVE_DECODED"
reject_text "Device#" "$SAVE_DECODED"
# The save path intentionally clears the window on completion, so the typed
# comment is verified in the on-disk header below rather than in this frame.
expect_text "Ok." "$SAVE_DECODED"

if [[ ! -f "$SAVE_FILE" ]]; then
    echo "FAIL: save file not found: $SAVE_FILE" >&2
    failures=$((failures + 1))
else
    python3 - "$SAVE_FILE" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = path.read_bytes()[:26]
errors = []

if data[0:6] != b"OZMSAV":
    errors.append(f"magic is {data[0:6]!r}, expected b'OZMSAV'")
if len(data) < 8 or data[6] != 1:
    errors.append(f"version byte is {data[6:7]!r}, expected 1")
if len(data) < 8 or data[7] != ord("0"):
    errors.append(f"slot byte is {data[7:8]!r}, expected b'0'")
# Neo returns lowercase ASCII, but the C64-style save-comment prompt stores
# uppercase letters. Typing "test save" therefore has to produce "TEST SAVE".
if len(data) < 22 or not data[8:22].startswith(b"TEST SAVE"):
    errors.append(f"comment bytes are {data[8:22]!r}, expected to start with b'TEST SAVE'")

if errors:
    print("FAIL: invalid save header:", file=sys.stderr)
    for error in errors:
        print(f"  {error}", file=sys.stderr)
    sys.exit(1)
PY
fi

echo "Changing location, then restoring in-session..."
send_line "open mailbox"
sleep "$COMMAND_DELAY"
send_line "restore"
sleep "$COMMAND_DELAY"

# The restore prompt must first list the occupied slots and their comments.
LIST_DECODED="$WORKDIR/list-decoded.txt"
capture_console "$WORKDIR/list-screen.png" "$LIST_DECODED"
expect_text "0: TEST SAVE" "$LIST_DECODED"
expect_text "1: (EMPTY)" "$LIST_DECODED"
expect_text "RESTORE FROM SLOT" "$LIST_DECODED"

send_line "0"
sleep "$FINAL_DELAY"

RESTORE_DECODED="$WORKDIR/restore-decoded.txt"
capture_console "$WORKDIR/restore-screen.png" "$RESTORE_DECODED"
reject_text "Disk error" "$RESTORE_DECODED"
reject_text "Device#" "$RESTORE_DECODED"
expect_text "West of House" "$RESTORE_DECODED"
reject_text "Opening the small mailbox reveals a leaflet." "$RESTORE_DECODED"

echo "Restarting emulator and restoring from the same storage..."
stop_emulator
start_emulator
send_line "restore"
sleep "$INPUT_DELAY"
send_line "0"
sleep "$FINAL_DELAY"

RESTART_DECODED="$WORKDIR/restart-decoded.txt"
capture_console "$WORKDIR/restart-screen.png" "$RESTART_DECODED"
reject_text "Disk error" "$RESTART_DECODED"
reject_text "Device#" "$RESTART_DECODED"
expect_text "West of House" "$RESTART_DECODED"

if ((failures > 0)); then
    echo "--- decoded console captures ---" >&2
    for decoded in "$SAVE_DECODED" "$RESTORE_DECODED" "$RESTART_DECODED"; do
        if [[ -f "$decoded" ]]; then
            echo "### $decoded" >&2
            cat "$decoded" >&2
        fi
    done
    echo "--- emulator log tail ---" >&2
    tail -40 "$LOG" >&2 || true
    exit 1
fi

echo "PASS: Neo6502 native save/restore test"
echo "  workdir:  $WORKDIR"
echo "  save file: $SAVE_FILE"
